classdef PR_MarmosetConePhenotypeFlow < handle
  % Two-field rivalry protocol for marmoset cone-phenotype screening.
  %
  % Each trial shows two contrast-matched contraction (converging) optic-flow
  % fields at once. Their flow centres follow independent random walks
  % from a pre-generated pair bank. If the animal sees both fields, gaze
  % divides between them; if one field is silent for its cones, the other
  % dominates. The stimulus always runs for its full duration: leaving
  % both centres never ends a trial, so "not seen" is recorded as a valid
  % choice of neither field rather than as an aborted, invalid trial.
  % Reward is non-differential: following either centre earns reward.
  %
  % Traces columns (one row per stimulus frame, degrees, +y up):
  %   1 eye-sample time, 2-3 centre A, 4-5 centre B, 6-7 eye, 8 pupil,
  %   9 stimulus displayed
  % ProbeHistory columns: flip time, centre A x/y (pix), centre B x/y (pix)
  % FixTraces columns: time, eye x, eye y, pupil (fixation states 1-2)

  properties (Access = public)
       Iti double = 1;            % default Iti duration
       startTime double = 0;      % trial start time
       fixStart double = 0;       % fix acquired time
       itiStart double = 0;       % start of ITI interval
       stimStart double = 0;      % stimulus onset
       lastUpdateTime double = 0; % previous stimulus-frame time
       followSeconds double = 0;  % cumulative post-onset following time
       fixDur double = 0;         % fixation duration
       showFix logical = true;    % trial start with fixation
       flashCounter double = 0;   % counts frames for the fixation flash
       rewardCount double = 0;    % counter for reward drops
       RunFixBreakSound double = 0;
       NeverBreakSoundTwice double = 0;
       MaxFrame double = 6000;
       ProbeHistory = []
       Traces = []
       FixTraces = []
       FixCount double = 0;
       FrameCount double = 0;
       pendingFlip logical = false;
       mode double = 1;
  end

  properties (Access = private)
    winPtr;
    state double = 0;
    error double = 0;
    S;
    P;
    trialsList;
    trialIndexer = [];
    hFix;
    hProbe = [];       % two stimuli.opticflow fields: A then B
    fixbreak_sound;
    fixbreak_sound_fs;
    D = struct;
    currentConditions = struct([]);
    currentPair = struct();
    currentTrialRow double = [];
    currentTrialIndex double = NaN;
    fieldSeeds double = [NaN NaN];
    trialCalibrationChecksum char = '';
  end

  methods (Access = public)
    function o = PR_MarmosetConePhenotypeFlow(winPtr)
      o.winPtr = winPtr;
      o.trialsList = [];
    end

    function state = get_state(o)
        state = o.state;
    end

    function initFunc(o,S,P)
        cors = 0;      % completed stimulus presentations
        reps = [1,2];  % failures to initiate or hold fixation repeat
        o.trialIndexer = marmoview.TrialIndexer(o.trialsList,P,cors,reps);
        o.error = 0;

        if P.mode ~= 1
            error('PR_MarmosetConePhenotypeFlow:Mode', ...
                'This protocol only supports optic-flow mode (P.mode = 1).');
        end
        o.hFix = stimuli.fixation(o.winPtr);
        o.hProbe = [stimuli.opticflow(o.winPtr) stimuli.opticflow(o.winPtr)];

        sz = P.fixPointRadius*S.pixPerDeg;
        o.hFix.cSize = sz;
        o.hFix.sSize = 2*sz;
        o.hFix.cColour = ones(1,3);
        o.hFix.sColour = repmat(255,1,3);
        o.hFix.position = [0,0]*S.pixPerDeg + S.centerPix;
        o.hFix.updateTextures();

        [y,fs] = audioread(['SupportData',filesep,'gunshot_sound.wav']);
        o.fixbreak_sound = y(1:floor(size(y,1)/3),:);
        o.fixbreak_sound_fs = fs;
    end

    function closeFunc(o)
        o.hFix.CloseUp();
        for k = 1:numel(o.hProbe)
            o.hProbe(k).CloseUp();
        end
    end

    function generate_trialsList(o,S,~)
        if ~isfield(S,'marmosetTrialPlan') || ...
                ~isfield(S.marmosetTrialPlan,'Rows') || ...
                ~isfield(S.marmosetTrialPlan,'Columns')
            error('PR_MarmosetConePhenotypeFlow:TrialPlan', ...
                'Settings are missing the fixed marmoset rivalry trial plan.');
        end
        o.trialsList = S.marmosetTrialPlan.Rows;
    end

    function P = next_trial(o,S,P)
        o.S = S;
        o.P = P;

        i = o.trialIndexer.getNextTrial(o.error);
        row = o.trialsList(i,:);
        columns = S.marmosetTrialPlan.Columns;
        value = @(name) row(strcmp(columns,name));
        o.currentTrialIndex = i;
        o.currentTrialRow = row;
        P.pairIndex = value('PairIndex');
        P.conditionIndexA = value('ConditionIndexA');
        P.conditionIndexB = value('ConditionIndexB');
        P.contrastLevelIndex = value('ContrastLevelIndex');
        P.trajectoryPairIndex = value('TrajectoryPairIndex');
        P.walkForA = value('WalkForA');
        P.repeatIndex = value('RepeatIndex');
        P.trialRandomSeed = value('TrialRandomSeed');
        P.rewardNumber = value('RewardAmount');
        P.cpd = P.pairIndex; % legacy plotting slot only
        P.choiceX = 0;
        P.choiceY = 0;
        P.xDeg = 0;
        P.yDeg = 0;

        bank = S.marmosetConditionBank;
        o.currentPair = S.marmosetTrialPlan.Pairs(P.pairIndex);
        o.currentConditions = bank.Conditions([P.conditionIndexA P.conditionIndexB]);
        o.trialCalibrationChecksum = bank.CalibrationChecksum;
        if ~all(strcmp({o.currentConditions.CalibrationChecksum}, ...
                o.trialCalibrationChecksum))
            error('PR_MarmosetConePhenotypeFlow:CalibrationChanged', ...
                'Condition calibration checksum changed before the trial.');
        end

        walks = [P.walkForA 3-P.walkForA];
        trajectories = S.marmosetTrajectoryBank;
        P.flowCentreAXDeg = squeeze(trajectories.XDeg(P.trajectoryPairIndex,walks(1),:))';
        P.flowCentreAYDeg = squeeze(trajectories.YDeg(P.trajectoryPairIndex,walks(1),:))';
        P.flowCentreBXDeg = squeeze(trajectories.XDeg(P.trajectoryPairIndex,walks(2),:))';
        P.flowCentreBYDeg = squeeze(trajectories.YDeg(P.trajectoryPairIndex,walks(2),:))';
        nFrames = numel(P.flowCentreAXDeg);
        o.MaxFrame = nFrames + ceil(S.frameRate);
        o.ProbeHistory = zeros(o.MaxFrame,5);
        o.Traces = nan(o.MaxFrame,9);
        o.FixTraces = nan(ceil(10*S.frameRate),4);

        seedStream = RandStream('mt19937ar','Seed',P.trialRandomSeed);
        o.fieldSeeds = [randi(seedStream,2^31-1) randi(seedStream,2^31-1)];
        starts = [P.flowCentreAXDeg(1) P.flowCentreAYDeg(1); ...
            P.flowCentreBXDeg(1) P.flowCentreBYDeg(1)];
        for k = 1:2
            o.configureField(o.hProbe(k),o.currentConditions(k), ...
                o.degToPix(starts(k,:)),o.fieldSeeds(k),P,S);
        end
        o.P = P;
    end

    function [FP,TS] = prep_run_trial(o)
        o.fixDur = o.P.fixMin + ceil(1000*o.P.fixRan*rand)/1000;
        o.showFix = true;
        o.flashCounter = 0;
        o.rewardCount = 0;
        o.followSeconds = 0;
        o.FrameCount = 0;
        o.FixCount = 0;
        o.pendingFlip = false;
        o.RunFixBreakSound = 0;
        o.NeverBreakSoundTwice = 0;
        o.state = 0;
        o.error = 0;
        o.Iti = o.P.iti;
        FP(1).states = 1:2;  % fixation
        FP(1).col = 'b';
        FP(2).states = 3;    % stimulus
        FP(2).col = 'g';
        TS = 1:3;
        o.startTime = GetSecs;
    end

    function keepgoing = continue_run_trial(o,screenTime)
        % Only the flip that displayed a stimulus frame is stored for it.
        if o.pendingFlip && o.FrameCount > 0
            o.ProbeHistory(o.FrameCount,1) = screenTime;
            o.pendingFlip = false;
        end
        keepgoing = o.state < 9;
    end

    function drop = state_and_screen_update(o,currentTime,x,y,varargin)
        drop = 0;
        pupil = o.readPupil(varargin{:});

        %%%%% STATE 0 -- GET INTO FIXATION WINDOW
        if o.state == 0 && norm([x y]) < o.P.initWinRadius
            o.state = 1;
            o.fixStart = GetSecs;
        end
        if o.state == 0 && currentTime > o.startTime + o.P.startDur
            o.state = 8;
            o.error = 1; % failure to initiate
            o.itiStart = GetSecs;
        end

        %%%%% STATES 1-2 -- FIXATION; samples give the pre-stimulus baseline
        if o.state == 1 || o.state == 2
            o.FixCount = min(o.FixCount+1,size(o.FixTraces,1));
            o.FixTraces(o.FixCount,:) = [currentTime x y pupil];
        end
        if o.state == 1 && currentTime > o.fixStart + o.P.fixGrace
            if norm([x y]) < o.P.initWinRadius
                o.state = 2;
            else
                o.state = 8;
                o.error = 1;
                o.itiStart = GetSecs;
            end
        end
        if o.state == 2 && currentTime > o.fixStart + o.fixDur
            o.state = 3;
            if isfield(o.P,'rewardFix') && o.P.rewardFix
                drop = 1;
            end
            o.stimStart = GetSecs;
            o.lastUpdateTime = currentTime;
        end
        if o.state == 2 && norm([x y]) > o.P.fixWinRadius
            o.state = 8;
            o.error = 2; % failure to hold fixation
            o.itiStart = GetSecs;
        end

        %%%%% STATE 3 -- BOTH FIELDS FOR THE FULL DURATION
        if o.state == 3 && currentTime > o.stimStart + o.P.stimDur
            o.state = 7;
            o.error = 0;
            o.itiStart = GetSecs;
        end
        if o.state == 3
            onsetOver = currentTime >= o.stimStart + ...
                o.S.marmosetConfig.OnsetExclusionSeconds;
            if onsetOver && o.gazeOnEitherCentre(x,y)
                o.followSeconds = o.followSeconds + ...
                    max(0,currentTime-o.lastUpdateTime);
                if o.rewardCount < o.P.rewardNumber && ...
                        o.followSeconds >= (o.rewardCount+1)*o.P.RewardDur
                    o.rewardCount = o.rewardCount + 1;
                    drop = 1;
                end
            end
            o.lastUpdateTime = currentTime;
        end

        %%%%% STATES 7-8 -- END OF TRIAL / FEEDBACK
        if o.state == 7
            o.state = 8;
        end
        if o.state == 8 && currentTime > o.itiStart + 0.2
            o.state = 9;
            if o.error
                o.Iti = o.P.iti + o.P.blank_iti;
            end
        end

        switch o.state
            case 0
                if o.showFix
                    o.hFix.beforeFrame(1);
                end
                o.flashCounter = mod(o.flashCounter+1,o.P.flashFrameLength);
                if o.flashCounter == 0
                    o.showFix = ~o.showFix;
                end
            case {1,2}
                o.hFix.beforeFrame(1);
            case 3
                o.updateFields(x,y,pupil,currentTime);
            case 8
                if o.error == 2
                    o.hFix.beforeFrame(2);
                    o.RunFixBreakSound = 1;
                end
        end

        if o.RunFixBreakSound == 1 && o.NeverBreakSoundTwice == 0
           sound(o.fixbreak_sound,o.fixbreak_sound_fs);
           o.NeverBreakSoundTwice = 1;
        end
    end

    function Iti = end_run_trial(o)
        Iti = o.Iti - (GetSecs - o.itiStart);
    end

    function plot_trace(o,handles)
        h = handles.EyeTrace;
        set(h,'NextPlot','Replace');
        r = o.P.fixWinRadius;
        plot(h,r*cos(0:.01:2*pi),r*sin(0:.01:2*pi),'--k');
        set(h,'NextPlot','Add');
        trialTraces = o.Traces(1:o.FrameCount,:);
        plot(h,trialTraces(:,2),trialTraces(:,3),'r.');
        plot(h,trialTraces(:,4),trialTraces(:,5),'m.');
        plot(h,trialTraces(:,6),trialTraces(:,7),'b.');
        eyeRad = handles.eyeTraceRadius;
        axis(h,[-eyeRad eyeRad -eyeRad eyeRad]);
    end

    function PR = end_plots(o,P,A)
        settings = o.S;
        config = settings.marmosetConfig;
        bank = settings.marmosetConditionBank;
        conditions = o.currentConditions;

        PR = struct;
        PR.error = o.error;
        PR.fixDur = o.fixDur;
        PR.x = P.xDeg;
        PR.y = P.yDeg;
        PR.choiceX = P.choiceX;
        PR.choiceY = P.choiceY;
        PR.cpd = P.cpd;
        PR.stimulusFamily = 'marmoset candidate-pigment rivalry flow';

        % Design and full stimulus definition (independent of settings files).
        PR.trialPlanSchemaVersion = settings.marmosetTrialPlan.SchemaVersion;
        PR.trialPlanColumns = settings.marmosetTrialPlan.Columns;
        PR.trialPlanRow = o.currentTrialRow;
        PR.trialPlanIndex = o.currentTrialIndex;
        PR.pairIndex = P.pairIndex;
        PR.pairID = o.currentPair.PairID;
        PR.pairType = o.currentPair.PairType;
        PR.conditionIndexA = P.conditionIndexA;
        PR.conditionIndexB = P.conditionIndexB;
        PR.conditionIDA = conditions(1).ConditionID;
        PR.conditionIDB = conditions(2).ConditionID;
        PR.fieldConditionA = conditions(1);
        PR.fieldConditionB = conditions(2);
        PR.contrastLevelIndex = P.contrastLevelIndex;
        PR.trajectoryPairIndex = P.trajectoryPairIndex;
        PR.walkForA = P.walkForA;
        PR.repeatIndex = P.repeatIndex;
        PR.trialRandomSeed = P.trialRandomSeed;
        PR.fieldRandomSeeds = o.fieldSeeds;
        PR.conditionBankSchemaVersion = bank.SchemaVersion;
        PR.backgroundLinearRGB = bank.BackgroundLinearRGB;
        PR.backgroundLuminanceCdM2 = bank.BackgroundLuminanceCdM2;
        PR.matchedContrast = bank.MatchedContrast;
        PR.calibrationSource = bank.CalibrationSource;
        PR.calibrationChecksum = bank.CalibrationChecksum;
        PR.monitorIdentifier = bank.MonitorIdentifier;
        PR.gammaApplication = conditions(1).GammaApplication;
        PR.onsetExclusionSeconds = config.OnsetExclusionSeconds;
        PR.flowCentreAXDeg = P.flowCentreAXDeg;
        PR.flowCentreAYDeg = P.flowCentreAYDeg;
        PR.flowCentreBXDeg = P.flowCentreBXDeg;
        PR.flowCentreBYDeg = P.flowCentreBYDeg;

        % Rendering as executed.
        PR.dotType = [o.hProbe.dotType];
        PR.exactColour = [o.hProbe.exactColour];
        PR.dotBlendFunction = {o.hProbe(1).lastBlendFunction, ...
            o.hProbe(2).lastBlendFunction};
        PR.dotDiameterPix = o.hProbe(1).size;
        PR.dotDiameterDeg = o.hProbe(1).size/settings.pixPerDeg;
        PR.requestedDotDiameterDeg = P.dotSizeDeg;
        PR.nDotsPerField = [o.hProbe.nDots];
        PR.dotNegativeCount = arrayfun(@(h) nnz(h.dotPolarity < 0),o.hProbe);
        PR.dotPositiveCount = arrayfun(@(h) nnz(h.dotPolarity > 0),o.hProbe);
        PR.dotNeutralCount = arrayfun(@(h) nnz(h.dotPolarity == 0),o.hProbe);
        PR.dotPlacementFallbacks = [o.hProbe.placementFallbackCount];
        PR.dotMinSeparationDeg = o.hProbe(1).minSeparationPix/settings.pixPerDeg;

        frameIntervals = diff(o.ProbeHistory(1:o.FrameCount,1));
        frameIntervals = frameIntervals(isfinite(frameIntervals) & frameIntervals > 0);
        PR.frameTimingThresholdMs = 1000*1.5/settings.frameRate;
        PR.longFrameCount = nnz(frameIntervals > 1.5/settings.frameRate);
        PR.longFrameFraction = PR.longFrameCount/max(1,numel(frameIntervals));
        PR.rewardCount = o.rewardCount;
        PR.followSecondsForReward = o.followSeconds;

        PR.Traces = o.Traces(1:o.FrameCount,:);
        PR.ProbeHistory = o.ProbeHistory(1:o.FrameCount,:);
        PR.FixTraces = o.FixTraces(1:o.FixCount,:);

        metricOptions = struct( ...
            'WindowRadiusDeg',P.targWinRadius, ...
            'OnsetExclusionSeconds',config.OnsetExclusionSeconds, ...
            'MinimumValidEyeSamples',config.MinimumValidEyeSamples, ...
            'MaximumEyeGapSeconds',config.MaximumEyeGapSeconds, ...
            'MaximumLongFrameFraction',config.MaximumLongFrameFraction, ...
            'MinimumDurationSeconds',config.MinimumAnalysisDurationSeconds, ...
            'ChoiceMinimumFraction',config.ChoiceMinimumFraction, ...
            'ChoiceMargin',config.ChoiceMargin, ...
            'ScreenHalfSizeDeg',settings.screenRect(3:4)/2/settings.pixPerDeg, ...
            'CalibrationStable',all(strcmp({conditions.CalibrationChecksum}, ...
                o.trialCalibrationChecksum)));
        if o.error ~= 0 || o.FrameCount == 0
            metrics = struct('TrialValid',false,'InvalidReasons', ...
                {{'stimulus not presented (fixation not acquired or held)'}}, ...
                'Choice','invalid','ChoiceCode',NaN);
        else
            metrics = marmoview.flowRivalryMetrics(PR.Traces,PR.FixTraces, ...
                PR.ProbeHistory(:,1),settings.frameRate,metricOptions);
        end
        PR.rivalryMetrics = metrics;
        PR.trialValid = metrics.TrialValid;
        PR.invalidReasons = metrics.InvalidReasons;
        PR.choice = metrics.Choice;
        PR.choiceCode = metrics.ChoiceCode;
        switch metrics.Choice
            case 'A'
                PR.choiceConditionID = PR.conditionIDA;
            case 'B'
                PR.choiceConditionID = PR.conditionIDB;
            otherwise
                PR.choiceConditionID = '';
        end
        if isfield(metrics,'PreferenceIndex')
            PR.preferenceIndex = metrics.PreferenceIndex;
            PR.followFractionA = metrics.FollowFractionA;
            PR.followFractionB = metrics.FollowFractionB;
            PR.velocityGainA = metrics.VelocityGainA;
            PR.velocityGainB = metrics.VelocityGainB;
            PR.validEyeSampleCount = metrics.ValidEyeSampleCount;
        end

        % Online summary: probability of following field A for each pair.
        o.D.pairIndex(A.j) = P.pairIndex;
        o.D.choiceCode(A.j) = PR.choiceCode;
        pairs = settings.marmosetTrialPlan.Pairs;
        fractionA = nan(1,numel(pairs));
        fractionNone = nan(1,numel(pairs));
        for k = 1:numel(pairs)
            codes = o.D.choiceCode(o.D.pairIndex == k & isfinite(o.D.choiceCode));
            if ~isempty(codes)
                fractionA(k) = mean(codes == 1);
                fractionNone(k) = mean(codes == 0);
            end
        end
        bar(A.DataPlot3,1:numel(pairs),[fractionA' fractionNone'],'stacked');
        title(A.DataPlot3,'Follow A (dark) / neither (light)');
        set(A.DataPlot3,'XTick',1:numel(pairs),'XTickLabel', ...
            strrep({pairs.PairID},'_scale_1',''),'XTickLabelRotation',45);
        axis(A.DataPlot3,[0.25 numel(pairs)+0.75 0 1]);

        if o.FrameCount > 0
            eye = PR.Traces(:,6:7);
            dA = hypot(PR.Traces(:,2)-eye(:,1),PR.Traces(:,3)-eye(:,2));
            dB = hypot(PR.Traces(:,4)-eye(:,1),PR.Traces(:,5)-eye(:,2));
            nearestA = dA <= dB;
            offsets = [PR.Traces(:,2:3)-eye PR.Traces(:,4:5)-eye];
            offsets(~nearestA,1:2) = offsets(~nearestA,3:4);
            plot(A.DataPlot1,0,0,'kx');
            plot(A.DataPlot1,offsets(:,1),offsets(:,2),'b.');
            set(A.DataPlot1,'DataAspectRatio',[1 1 1], ...
                'XLim',[-1 1]*2*P.targWinRadius,'YLim',[-1 1]*2*P.targWinRadius);
            title(A.DataPlot1,'Eye to nearest centre');
            if isfield(metrics,'FieldA')
                plot(A.DataPlot2,metrics.FieldA.CrossCorrelationLagsSeconds, ...
                    metrics.FieldA.EyeCentreCrossCorrelation,'r', ...
                    metrics.FieldB.CrossCorrelationLagsSeconds, ...
                    metrics.FieldB.EyeCentreCrossCorrelation,'m');
                title(A.DataPlot2,sprintf('Velocity CCG: A %s, B %s', ...
                    PR.conditionIDA,PR.conditionIDB),'Interpreter','none');
            end
        end
    end
  end

  methods (Access = private)
    function configureField(o,field,condition,positionPix,seed,P,S)
        field.position = positionPix;
        field.f = 0.100;
        field.depth = 10;
        field.dotType = S.marmosetConfig.DotType;
        field.exactColour = true;
        [~,~,minSize,maxSize] = Screen('DrawDots',o.winPtr);
        field.size = min(max(P.dotSizeDeg*S.pixPerDeg,minSize),maxSize);
        field.vxyz = [0 0 -abs(P.flowExpansionSpeed)];
        field.nDots = max(2,round(P.nDots/2));
        field.pixperdeg = S.pixPerDeg;
        field.screenRect = S.screenRect;
        field.bkgd = mean(condition.BackgroundFramebufferRGB255);
        field.balancedDots = true;
        field.dotContrast = 1;
        field.polarityColours = [condition.NegativeFramebufferRGB255(:), ...
            condition.PositiveFramebufferRGB255(:)];
        field.neutralColour = condition.BackgroundFramebufferRGB255(:);
        field.minSeparationPix = max(0,P.dotMinSeparation)*S.pixPerDeg;
        field.placementAttempts = max(1,round(P.dotPlacementAttempts));
        field.maxRadius = inf;
        field.lifetime = max(1,round(P.dotLifetimeFrames));
        field.setCenterDecayProfile(P.centerDecayProfile);
        field.Xtop = S.screenRect(3);
        field.Xbot = S.screenRect(1);
        field.Ytop = S.screenRect(2);
        field.Ybot = S.screenRect(4);
        field.setRandomSeed(seed);
        field.beforeTrial();
    end

    function updateFields(o,x,y,pupil,currentTime)
        o.FrameCount = min(o.FrameCount + 1,o.MaxFrame);
        frame = min(o.FrameCount,numel(o.P.flowCentreAXDeg));
        centres = [o.P.flowCentreAXDeg(frame) o.P.flowCentreAYDeg(frame); ...
            o.P.flowCentreBXDeg(frame) o.P.flowCentreBYDeg(frame)];
        for k = 1:2
            o.hProbe(k).afterFrame();
            o.hProbe(k).position = o.degToPix(centres(k,:));
        end
        % Alternate draw order so neither field systematically occludes the other.
        order = [1 2];
        if mod(o.FrameCount,2) == 0
            order = [2 1];
        end
        for k = order
            o.hProbe(k).beforeFrame();
        end
        % Centres displayed on this frame; eye sampled just before its flip.
        o.Traces(o.FrameCount,:) = [currentTime centres(1,:) centres(2,:) ...
            x y pupil 1];
        o.ProbeHistory(o.FrameCount,2:5) = [o.hProbe(1).position o.hProbe(2).position];
        o.pendingFlip = true;
    end

    function tf = gazeOnEitherCentre(o,x,y)
        tf = false;
        if o.FrameCount < 1
            return
        end
        frame = min(o.FrameCount,numel(o.P.flowCentreAXDeg));
        dA = hypot(x-o.P.flowCentreAXDeg(frame),y-o.P.flowCentreAYDeg(frame));
        dB = hypot(x-o.P.flowCentreBXDeg(frame),y-o.P.flowCentreBYDeg(frame));
        tf = min(dA,dB) <= o.P.targWinRadius;
    end

    function pixel = degToPix(o,deg)
        pixel = [o.S.centerPix(1) + round(deg(1)*o.S.pixPerDeg), ...
            o.S.centerPix(2) - round(deg(2)*o.S.pixPerDeg)];
    end

    function pupil = readPupil(~,varargin)
        % Pupil size from the first input that reports it; NaN if none does.
        pupil = NaN;
        if isempty(varargin) || ~iscell(varargin{1})
            return
        end
        inputs = varargin{1};
        for k = 1:numel(inputs)
            if ismethod(inputs{k},'getpupil') && ismethod(inputs{k},'getgaze')
                try
                    pupil = double(inputs{k}.getpupil());
                catch
                    pupil = NaN;
                end
                if isempty(pupil)
                    pupil = NaN;
                end
                pupil = pupil(1);
                return
            end
        end
    end
  end
end
