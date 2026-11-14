function test_marmoset_protocol_simulation
% TEST_MARMOSET_PROTOCOL_SIMULATION Simulated session through the real protocol.
%
% Screen and GetSecs are replaced by stubs (a simulated 60 Hz clock), and a
% simulated 556-dichromat observer supplies gaze: it follows whichever field
% gives its 556 cone the larger contrast and holds fixation when neither is
% visible. Every twelfth trial loses the eye for 0.5 s. The saved trials
% are then analyzed blind.

taskRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(taskRoot,'Analysis'));
stubFolder = tempname;
mkdir(stubFolder);
writeStubs(stubFolder);
addpath(stubFolder,'-begin');
cleanupStubs = onCleanup(@() removeStubs(stubFolder));
previousFolder = cd(taskRoot); % the protocol loads SupportData/gunshot_sound.wav
cleanupFolder = onCleanup(@() cd(previousFolder));
warning('off','marmosetPigmentNull:SilentLeakageWarning');
cleanupWarning = onCleanup(@() warning('on','marmosetPigmentNull:SilentLeakageWarning'));
global MARMOSET_TEST_CLOCK MARMOSET_TEST_DRAWS %#ok<GVMIS>
MARMOSET_TEST_CLOCK = 0;
MARMOSET_TEST_DRAWS = {};

[S,P] = simulatedSettings();
bank = S.marmosetConditionBank;
frameRate = S.frameRate;
nFrames = size(S.marmosetTrajectoryBank.XDeg,3);
tracker = MarmosetTestTracker();
figureHandle = figure('Visible','off');
cleanupFigure = onCleanup(@() close(figureHandle));
A = struct('DataPlot1',subplot(1,3,1),'DataPlot2',subplot(1,3,2), ...
    'DataPlot3',subplot(1,3,3),'j',1);

protocol = protocols.PR_MarmosetConePhenotypeFlow(1);
protocol.generate_trialsList(S,P);
protocol.initFunc(S,P);
nTrials = size(S.marmosetTrialPlan.Rows,1);
D = cell(nTrials,1);
dropTimes = cell(nTrials,1);
onsetTimes = nan(nTrials,1);
for trial = 1:nTrials
    A.j = trial;
    MARMOSET_TEST_DRAWS = {};
    trialP = protocol.next_trial(S,P);
    protocol.prep_run_trial();
    target = observerTarget(bank,trialP);
    stimulusFrame = 0;
    loseEye = mod(trial,12) == 0;
    while true
        MARMOSET_TEST_CLOCK = MARMOSET_TEST_CLOCK + 1/frameRate;
        currentTime = GetSecs;
        if protocol.get_state() == 3
            stimulusFrame = stimulusFrame + 1;
            if isnan(onsetTimes(trial))
                onsetTimes(trial) = currentTime;
            end
        end
        [x,y] = observerGaze(trialP,target,stimulusFrame,frameRate);
        tracker.Pupil = 1;
        if loseEye && stimulusFrame >= 40 && stimulusFrame < 70
            x = NaN;
            y = NaN;
            tracker.Pupil = NaN;
        end
        drop = protocol.state_and_screen_update(currentTime,x,y,{tracker});
        if drop
            dropTimes{trial}(end+1) = currentTime;
        end
        if ~protocol.continue_run_trial(currentTime + 0.002)
            break
        end
    end
    PR = protocol.end_plots(trialP,A);
    D{trial} = struct('PR',PR,'P',trialP);
    draws = MARMOSET_TEST_DRAWS;
    assert(all(cellfun(@(d) d.type == 0,draws)), 'Dots must be square (type 0).');
    assert(all(cellfun(@(d) isequal(d.blend,{'GL_ONE','GL_ZERO'}),draws)), ...
        'Dots must be drawn with blending off.');
    allowed = [PR.fieldConditionA.NegativeFramebufferRGB255; ...
        PR.fieldConditionA.PositiveFramebufferRGB255; ...
        PR.fieldConditionB.NegativeFramebufferRGB255; ...
        PR.fieldConditionB.PositiveFramebufferRGB255; ...
        PR.fieldConditionA.BackgroundFramebufferRGB255];
    for k = 1:numel(draws)
        assert(all(ismember(draws{k}.colours,allowed,'rows')), ...
            'A drawn colour is not one of the calibrated endpoints.');
    end
    MARMOSET_TEST_CLOCK = MARMOSET_TEST_CLOCK + protocol.end_run_trial();
end

% Every planned trial ran for its full duration, including unseen ones.
errors = cellfun(@(d) d.PR.error,D);
assert(all(errors == 0));
for trial = 1:nTrials
    PR = D{trial}.PR;
    assert(size(PR.Traces,1) >= nFrames);
    flips = PR.ProbeHistory(:,1);
    assert(all(flips > 0) && all(diff(flips) > 0));
    assert(isequal(PR.dotBlendFunction{1},{'GL_ONE','GL_ZERO'}));
    assert(all(PR.dotNegativeCount == PR.dotPositiveCount));
    assert(all(dropTimes{trial} >= onsetTimes(trial) + ...
        S.marmosetConfig.OnsetExclusionSeconds));
end

% Only the trials with a tracker dropout are invalid.
valid = cellfun(@(d) d.PR.trialValid,D);
lostEye = mod((1:nTrials)',12) == 0;
assert(isequal(~valid,lostEye));
assert(all(cellfun(@(d) any(strcmp(d.PR.invalidReasons, ...
    'eye tracker lost the animal')),D(lostEye))));

% Unseen fields yield valid "neither" choices, not invalid trials.
types = cellfun(@(d) d.PR.pairType,D,'UniformOutput',false);
choices = cellfun(@(d) d.PR.choice,D,'UniformOutput',false);
catchCatch = strcmp(types,'catch-catch') & valid;
assert(any(catchCatch) && all(strcmp(choices(catchCatch),'none')));
unseen = cellfun(@(d) strcmp(d.PR.conditionIDA,'null556_scale_1') && ...
    strcmp(d.PR.pairType,'null-catch'),D) & valid;
assert(any(unseen) && all(strcmp(choices(unseen),'none')));

% Two identical visible fields: valid, followed, and split between A and B.
baseline = strcmp(types,'achromatic-achromatic') & valid;
assert(any(baseline) && any(strcmp(choices(baseline),'A')) && ...
    any(strcmp(choices(baseline),'B')) && ~any(strcmp(choices(baseline),'none')));

analysis = analyzeMarmosetConePhenotypeFlow(D,struct('BootstrapIterations',20));
assert(contains(analysis.RuleBasedInterpretation,'556 dichromat'));
assert(strcmp(analysis.PhenotypeModel.BestPhenotype,'D_556'));
assert(analysis.ValidTrialCount == nnz(valid));

clear cleanupFigure cleanupWarning cleanupFolder cleanupStubs
fprintf('test_marmoset_protocol_simulation: all tests passed.\n');
end


function [S,P] = simulatedSettings()
fixture = make_synthetic_marmoset_calibration;
S = struct();
S.frameRate = 60;
S.pixPerDeg = 30;
S.screenRect = [0 0 1200 800];
S.centerPix = S.screenRect(3:4)/2;
config = struct('OnsetExclusionSeconds',0.3,'DotType',0, ...
    'MinimumValidEyeSamples',60,'MaximumEyeGapSeconds',0.3, ...
    'MaximumLongFrameFraction',0.05,'MinimumAnalysisDurationSeconds',1, ...
    'ChoiceMinimumFraction',0.25,'ChoiceMargin',0.1);
S.marmosetConfig = config;
S.marmosetConditionBank = marmoview.marmosetPhenotypeConditionBank(fixture, ...
    struct('ExpectedMonitorIdentifier','SYNTHETIC_TEST_MONITOR','BackgroundStepSize',0.02));
S.marmosetTrajectoryBank = marmoview.makeMarmosetFlowTrajectoryBank(struct( ...
    'FrameRate',60,'StimulusDuration',2,'TrajectoryPairCount',6,'RandomSeed',3, ...
    'SpeedDegPerSecond',6,'MaximumEccentricityDeg',6,'FilterTimeConstantSeconds',0.3));
S.marmosetTrialPlan = marmoview.makeMarmosetPhenotypeTrialPlan( ...
    S.marmosetConditionBank,struct('RepeatsPerPair',12,'TrajectoryPairCount',6, ...
    'RandomSeed',4,'CatchTrialFraction',0.1,'RewardAmount',3));
P = struct('mode',1,'PreserveTrialOrder',1,'RepeatUntilCorrect',0, ...
    'fixPointRadius',0.35,'initWinRadius',1,'fixWinRadius',2,'targWinRadius',2, ...
    'startDur',4,'flashFrameLength',30,'fixGrace',0.05,'fixMin',0.2,'fixRan',0.1, ...
    'stimDur',2,'RewardDur',0.5,'iti',0.5,'blank_iti',0.5,'rewardNumber',3, ...
    'rewardFix',0,'nDots',400,'dotSizeDeg',0.15,'flowExpansionSpeed',0.1, ...
    'dotLifetimeFrames',30,'dotMinSeparation',0.25,'dotPlacementAttempts',20, ...
    'centerDecayProfile',1);
end


function target = observerTarget(bank,P)
% The 556 dichromat follows the field with the larger 556-cone contrast.
signal = zeros(1,2);
indices = [P.conditionIndexA P.conditionIndexB];
for k = 1:2
    contrast = bank.Conditions(indices(k)).RealizedConeContrast;
    signal(k) = abs(contrast(2,2)-contrast(1,2))/2;
end
[best,target] = max(signal);
if abs(signal(1)-signal(2)) < 1e-12
    target = 1 + mod(P.repeatIndex,2); % identical fields: alternate
end
if best < 0.01
    target = 0;
end
end


function [x,y] = observerGaze(P,target,stimulusFrame,frameRate)
lagFrames = round(0.2*frameRate);
if target == 0 || stimulusFrame <= lagFrames
    x = 0;
    y = 0;
    return
end
frame = min(stimulusFrame-lagFrames,numel(P.flowCentreAXDeg));
if target == 1
    x = P.flowCentreAXDeg(frame);
    y = P.flowCentreAYDeg(frame);
else
    x = P.flowCentreBXDeg(frame);
    y = P.flowCentreBYDeg(frame);
end
end


function writeStubs(folder)
writeFile(fullfile(folder,'Screen.m'),{
    'function varargout = Screen(command,varargin)'
    '% Test stub: records dot draws and tracks the blend function.'
    'persistent blend'
    'global MARMOSET_TEST_DRAWS'
    'if isempty(blend), blend = {''GL_SRC_ALPHA'',''GL_ONE_MINUS_SRC_ALPHA''}; end'
    'varargout = cell(1,nargout);'
    'switch command'
    '    case ''DrawDots'''
    '        if numel(varargin) == 1'
    '            varargout = {1,20,1,64};'
    '        else'
    '            colours = unique(varargin{4}(1:3,:)'',''rows'');'
    '            MARMOSET_TEST_DRAWS{end+1} = struct(''colours'',colours, ...'
    '                ''type'',varargin{6},''blend'',{blend});'
    '        end'
    '    case ''BlendFunction'''
    '        varargout = blend(1:max(nargout,0));'
    '        if numel(varargin) >= 3'
    '            blend = varargin(2:3);'
    '        end'
    'end'
    'end'});
writeFile(fullfile(folder,'GetSecs.m'),{
    'function t = GetSecs'
    'global MARMOSET_TEST_CLOCK'
    't = MARMOSET_TEST_CLOCK;'
    'end'});
writeFile(fullfile(folder,'MarmosetTestTracker.m'),{
    'classdef MarmosetTestTracker < handle'
    '    properties'
    '        Pupil double = 1;'
    '    end'
    '    methods'
    '        function [x,y] = getgaze(~)'
    '            x = 0; y = 0;'
    '        end'
    '        function r = getpupil(o)'
    '            r = o.Pupil;'
    '        end'
    '    end'
    'end'});
rehash;
end


function writeFile(filename,lines)
file = fopen(filename,'w');
fprintf(file,'%s\n',lines{:});
fclose(file);
end


function removeStubs(folder)
rmpath(folder);
rmdir(folder,'s');
clear Screen GetSecs
rehash;
end
