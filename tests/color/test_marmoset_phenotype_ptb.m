function report = test_marmoset_phenotype_ptb(S,P,options)
% TEST_MARMOSET_PHENOTYPE_PTB Operator-run display test of the real rendering path.
%
% report = test_marmoset_phenotype_ptb()            % uses the experiment settings
% report = test_marmoset_phenotype_ptb(S,P,options)
%
% Opens the display through marmoview.openScreen exactly as MarmoV6 does,
% runs one trial of each pair type through PR_MarmosetConePhenotypeFlow
% (gaze held at fixation), and checks:
%   - gamma is applied once: the hardware gamma table is identity and the
%     displayed (front-buffer) pixels equal the software-encoded codes;
%   - every displayed pixel is the background or one of the two fields'
%     calibrated endpoints (no anti-aliasing, blending, or clipping);
%   - both polarities of every visible field are on screen;
%   - flip timing.
% Options: WindowRect (default [] = full screen), StimulusSeconds (1),
% CaptureFrame (20), RequireHardwareGammaCheck (true; fail when the driver
% does not expose its gamma table).

if nargin < 2 || isempty(S)
    [S,P] = MarmosetConePhenotypeFlow;
end
if nargin < 3 || isempty(options)
    options = struct();
end
options = setDefault(options,'WindowRect',[]);
options = setDefault(options,'StimulusSeconds',1);
options = setDefault(options,'CaptureFrame',20);
options = setDefault(options,'RequireHardwareGammaCheck',true);

taskRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
previousFolder = cd(taskRoot);
cleanupFolder = onCleanup(@() cd(previousFolder));

% Never let openScreen change the display mode during a test.
S.frameRate = Screen('FrameRate',S.screenNumber);
if S.frameRate == 0
    S.frameRate = 60;
end
if ~isempty(options.WindowRect)
    S.DummyScreen = true;
    S.screenRect = options.WindowRect;
    S.centerPix = S.screenRect(3:4)/2;
end
P.stimDur = options.StimulusSeconds;

% Read the hardware gamma table before any window exists: on drivers that
% refuse the query, Psychtoolbox closes all open windows.
report = struct();
try
    gammaTable = Screen('ReadNormalizedGammaTable',S.screenNumber);
    identity = linspace(0,1,size(gammaTable,1))';
    report.HardwareGammaMaximumDeviation = max(abs(gammaTable-identity),[],'all');
catch
    report.HardwareGammaMaximumDeviation = NaN;
end

A = marmoview.openScreen(S,struct());
cleanupScreen = onCleanup(@() sca);
report.GammaApplication = A.gammaApplication;
if ~strcmp(A.gammaApplication,'software-encoded empirical device values')
    error('test_marmoset_phenotype_ptb:GammaPipeline', ...
        'openScreen added a Psychtoolbox gamma stage for this protocol.');
end
if isnan(report.HardwareGammaMaximumDeviation)
    if options.RequireHardwareGammaCheck
        error('test_marmoset_phenotype_ptb:HardwareGammaUnreadable', ...
            ['The graphics driver does not expose its gamma table, so a second ' ...
            'gamma stage cannot be excluded. Verify with a photometer.']);
    end
    warning('test_marmoset_phenotype_ptb:HardwareGammaUnreadable', ...
        'Hardware gamma table unreadable; the identity check was skipped.');
elseif report.HardwareGammaMaximumDeviation > 1/255
    error('test_marmoset_phenotype_ptb:HardwareGamma', ...
        ['The graphics card gamma table is not identity (max deviation %.4f); ' ...
        'gamma would be applied twice. Reset colour management/night light.'], ...
        report.HardwareGammaMaximumDeviation);
end

figureHandle = figure('Visible','off');
cleanupFigure = onCleanup(@() close(figureHandle));
plots = struct('DataPlot1',subplot(1,3,1),'DataPlot2',subplot(1,3,2), ...
    'DataPlot3',subplot(1,3,3),'j',1);
protocol = protocols.PR_MarmosetConePhenotypeFlow(A.window);
protocol.generate_trialsList(S,P);
protocol.initFunc(S,P);

plan = S.marmosetTrialPlan;
pairTypes = {plan.Pairs.PairType};
typesToTest = unique(pairTypes,'stable');
template = struct('PairType','','PairID','','AllowedColours',[], ...
    'BackBufferColours',[],'FrontBufferColours',[],'PolarityPixelCounts',[], ...
    'LongFrameFraction',NaN,'Pass',false);
report.Trials = repmat(template,0,1);
trialsRun = 0;
while ~isempty(typesToTest) && trialsRun < size(plan.Rows,1)
    trialsRun = trialsRun + 1;
    plots.j = trialsRun;
    trialP = protocol.next_trial(S,P);
    pair = plan.Pairs(trialP.pairIndex);
    if ~ismember(pair.PairType,typesToTest)
        protocol.prep_run_trial();
        protocol.end_plots(trialP,plots);
        continue
    end
    typesToTest(strcmp(typesToTest,pair.PairType)) = [];
    bank = S.marmosetConditionBank;
    fields = bank.Conditions([trialP.conditionIndexA trialP.conditionIndexB]);
    allowed = unique(round([fields(1).BackgroundFramebufferRGB255; ...
        fields(1).NegativeFramebufferRGB255; fields(1).PositiveFramebufferRGB255; ...
        fields(2).NegativeFramebufferRGB255; fields(2).PositiveFramebufferRGB255]),'rows');
    protocol.prep_run_trial();
    backColours = [];
    frontColours = [];
    polarityCounts = [];
    flips = [];
    while true
        protocol.state_and_screen_update(GetSecs,0,0,{});
        if protocol.FrameCount == options.CaptureFrame && isempty(backColours)
            back = Screen('GetImage',A.window,[],'drawBuffer');
            backColours = unique(reshape(double(back),[],3),'rows');
        end
        vbl = Screen('Flip',A.window);
        if protocol.FrameCount > 0 && protocol.pendingFlip
            flips(end+1) = vbl; %#ok<AGROW>
        end
        if protocol.FrameCount == options.CaptureFrame && isempty(frontColours) && ...
                ~isempty(backColours)
            front = Screen('GetImage',A.window,[],'frontBuffer');
            pixels = reshape(double(front),[],3);
            frontColours = unique(pixels,'rows');
            polarityCounts = zeros(1,4);
            endpoints = [fields(1).NegativeFramebufferRGB255; fields(1).PositiveFramebufferRGB255; ...
                fields(2).NegativeFramebufferRGB255; fields(2).PositiveFramebufferRGB255];
            for k = 1:4
                polarityCounts(k) = nnz(all(pixels == round(endpoints(k,:)),2));
            end
        end
        if ~protocol.continue_run_trial(vbl)
            break
        end
    end
    protocol.end_plots(trialP,plots);
    intervals = diff(flips);
    item = template;
    item.PairType = pair.PairType;
    item.PairID = pair.PairID;
    item.AllowedColours = allowed;
    item.BackBufferColours = backColours;
    item.FrontBufferColours = frontColours;
    item.PolarityPixelCounts = polarityCounts;
    item.LongFrameFraction = mean(intervals > 1.5/S.frameRate);
    visible = [~strcmp(fields(1).ConditionType,'catch') ~strcmp(fields(2).ConditionType,'catch')];
    item.Pass = all(ismember(backColours,allowed,'rows')) && ...
        all(ismember(frontColours,allowed,'rows')) && ...
        all(polarityCounts([visible(1) visible(1) visible(2) visible(2)]) > 0);
    report.Trials(end+1,1) = item;
    if ~item.Pass
        strayBack = backColours(~ismember(backColours,allowed,'rows'),:);
        strayFront = frontColours(~ismember(frontColours,allowed,'rows'),:);
        error('test_marmoset_phenotype_ptb:Framebuffer', ...
            ['Pair %s: allowed %s; unexpected back-buffer colours %s; ' ...
            'unexpected front-buffer colours %s; polarity pixel counts %s.'], ...
            pair.PairID,mat2str(allowed),mat2str(strayBack(1:min(end,8),:)), ...
            mat2str(strayFront(1:min(end,8),:)),mat2str(polarityCounts));
    end
end
report.Pass = all([report.Trials.Pass]);
clear cleanupFigure cleanupScreen cleanupFolder
fprintf('test_marmoset_phenotype_ptb: %d pair types passed; hardware gamma deviation %.4f.\n', ...
    numel(report.Trials),report.HardwareGammaMaximumDeviation);
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
