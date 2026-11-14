function [S,P] = HumanConeCheckFlow
% HUMANCONECHECKFLOW Human L/M cone check with the two-field rivalry flow task.
%
% Same protocol, walks, and scoring as MarmosetConePhenotypeFlow, but with
% human cone-isolating fields: nullL (M cone only) and nullM (L cone only),
% plus achromatic and catch. With the mouse "eye tracker", start each trial
% by placing the cursor on the fixation point, then move it to the centre
% of whichever swarm you see; leave it still if you see neither.

S = MarmoViewRigSettings;
S.MarmoViewVersion = '6';
S.protocol = 'HumanConeCheckFlow';
S.protocol_class = 'protocols.PR_MarmosetConePhenotypeFlow';
S.protocolTitle = 'Human cone check';
S.TimeSensitive = 1:3;

taskRoot = fileparts(fileparts(mfilename('fullpath')));
proxyCalibration = fullfile(taskRoot,'SupportData','ConeCalibration', ...
    'HumanIsoluminantML','ConeMath2026_proxy_results.mat');
if isfield(S,'humanConeCalibrationFile') && exist(S.humanConeCalibrationFile,'file')
    calibrationFile = S.humanConeCalibrationFile;
else
    calibrationFile = proxyCalibration;
end
if ~exist(calibrationFile,'file')
    error('HumanConeCheckFlow:CalibrationUnavailable', ...
        'Human cone calibration not found: %s',calibrationFile);
end
allowDummy = isfield(S,'allowDummyHumanConeCalibration') && ...
    logical(S.allowDummyHumanConeCalibration);

c = struct();
c.CalibrationFile = calibrationFile;
c.MatchedContrastFraction = 0.95;
c.SilentLeakageTolerance = 0.005;
c.RelativeLeakageTolerance = 0.10;
c.RepeatsPerPair = 10;
c.TrajectoryPairCount = 5;
c.IncludeDetectionPairs = true;
c.IncludeAchromaticPairs = false;
c.CatchTrialFraction = 0.10;
c.RandomSeed = 20261010;
c.TrialDurationSeconds = 4;
c.OnsetExclusionSeconds = 0.30;
c.DotSizeDeg = 0.15;
c.DotCount = 1100;
c.DotType = 0;
c.FlowExpansionSpeed = 0.10;
c.DotLifetimeFrames = 30;
c.MinimumDotSeparationDeg = 0.25;
c.DotPlacementAttempts = 50;
c.FlowCentreSpeedDegPerSecond = 4;
c.FlowCentreMaximumEccentricityDeg = 7;
c.FlowCentreFilterTimeConstantSeconds = 0.3;
c.FlowCentreStartOffsetDeg = 2.5;
c.MinimumCentreSeparationDeg = 4;
c.MaximumCentreVelocityCorrelation = 0.2;
c.FollowWindowRadiusDeg = 2;
c.MinimumValidEyeSamples = round(S.frameRate);
c.MaximumEyeGapSeconds = 0.3;
c.MaximumLongFrameFraction = 0.05;
c.MinimumAnalysisDurationSeconds = 1;
c.ChoiceMinimumFraction = 0.25;
c.ChoiceMargin = 0.10;

bankOptions = struct('AllowDummy',allowDummy, ...
    'MatchedContrastFraction',c.MatchedContrastFraction, ...
    'SilentLeakageTolerance',c.SilentLeakageTolerance, ...
    'RelativeLeakageTolerance',c.RelativeLeakageTolerance);
probe = marmoview.loadHumanConeCalibration(calibrationFile,struct('AllowDummy',allowDummy));
if ~probe.IsDummyCalibration
    bankOptions.ExpectedMonitorIdentifier = S.monitor;
end
bank = marmoview.humanConeCheckConditionBank(calibrationFile,bankOptions);
c.CalibrationChecksum = bank.CalibrationChecksum;
S.marmosetConfig = c;
S.marmosetConditionBank = bank;
if bank.IsDummyCalibration
    S.protocolTitle = 'PROXY Human cone check';
    warning('HumanConeCheckFlow:ProxyCalibration', ...
        ['Proxy spectra and assumed gamma are active: the "silent" cone is ' ...
        'only approximately silent. Use for a visual demonstration, not a diagnosis.']);
end

screenHalfHeightDeg = S.screenRect(4)/2/S.pixPerDeg;
if c.FlowCentreMaximumEccentricityDeg + c.FollowWindowRadiusDeg > screenHalfHeightDeg
    error('HumanConeCheckFlow:ScreenSize', ...
        'Flow centres plus following window exceed the %.1f deg screen half-height.', ...
        screenHalfHeightDeg);
end
if ~strcmpi(bank.Conditions(1).GammaApplication,'software-encoded')
    error('HumanConeCheckFlow:GammaPolicy','Software-encoded empirical gamma is required.');
end
S.gammaApplication = 'software-encoded';

S.marmosetTrajectoryBank = marmoview.makeMarmosetFlowTrajectoryBank(struct( ...
    'FrameRate',S.frameRate, ...
    'StimulusDuration',c.TrialDurationSeconds, ...
    'TrajectoryPairCount',c.TrajectoryPairCount, ...
    'RandomSeed',c.RandomSeed, ...
    'SpeedDegPerSecond',c.FlowCentreSpeedDegPerSecond, ...
    'MaximumEccentricityDeg',c.FlowCentreMaximumEccentricityDeg, ...
    'FilterTimeConstantSeconds',c.FlowCentreFilterTimeConstantSeconds, ...
    'StartOffsetDeg',c.FlowCentreStartOffsetDeg, ...
    'MinimumCentreSeparationDeg',c.MinimumCentreSeparationDeg, ...
    'MaximumVelocityCorrelation',c.MaximumCentreVelocityCorrelation));
S.marmosetTrialPlan = marmoview.makeMarmosetPhenotypeTrialPlan(bank,struct( ...
    'RepeatsPerPair',c.RepeatsPerPair, ...
    'TrajectoryPairCount',c.TrajectoryPairCount, ...
    'RandomSeed',c.RandomSeed, ...
    'RewardAmount',0, ...
    'CatchTrialFraction',c.CatchTrialFraction, ...
    'IncludeDetectionPairs',c.IncludeDetectionPairs, ...
    'IncludeAchromaticPairs',c.IncludeAchromaticPairs));
S.finish = size(S.marmosetTrialPlan.Rows,1);
S.bgColour = bank.Conditions(1).BackgroundFramebufferRGB255;

P.RepeatUntilCorrect = 0;
S.RepeatUntilCorrect = 'Repeat incomplete trials? (0 or 1):';
P.PreserveTrialOrder = 1;
S.PreserveTrialOrder = 'Preserve constrained trial order (must remain 1):';
P.rewardNumber = 0;
S.rewardNumber = 'Maximum reward pulses:';
P.rewardFix = 0;
S.rewardFix = 'Reward fixation acquisition?';
P.runType = 1;
S.runType = 'Use fixed trial plan (must remain 1):';
P.mode = 1;
S.mode = 'Optic flow mode (must remain 1):';
P.bkgd = mean(S.bgColour);
S.bkgd = 'Legacy scalar background (fixed by calibration):';
P.nDots = c.DotCount;
S.nDots = 'Dot count, both fields:';
P.dotSizeDeg = c.DotSizeDeg;
S.dotSizeDeg = 'Dot width (deg):';
P.flowExpansionSpeed = c.FlowExpansionSpeed;
S.flowExpansionSpeed = 'Optic-flow contraction speed:';
P.dotLifetimeFrames = c.DotLifetimeFrames;
S.dotLifetimeFrames = 'Dot lifetime (frames):';
P.dotMinSeparation = c.MinimumDotSeparationDeg;
S.dotMinSeparation = 'Minimum same-polarity dot separation (deg):';
P.dotPlacementAttempts = c.DotPlacementAttempts;
S.dotPlacementAttempts = 'Dot-placement attempts:';
P.centerDecayProfile = 1;
S.centerDecayProfile = 'Centre cull: 0-off, 1-laser, 2-TDM:';
P.initWinRadius = 1;
S.initWinRadius = 'Enter-fixation window (deg):';
P.fixWinRadius = 2;
S.fixWinRadius = 'Fixation window (deg):';
P.targWinRadius = c.FollowWindowRadiusDeg;
S.targWinRadius = 'Flow-centre following window (deg):';
P.fixPointRadius = 0.35;
S.fixPointRadius = 'Fixation point radius (deg):';
P.startDur = 10;
S.startDur = 'Time to acquire fixation (s):';
P.flashFrameLength = 30;
S.flashFrameLength = 'Fixation flash duration (frames):';
P.fixGrace = 0.05;
S.fixGrace = 'Fixation grace period (s):';
P.fixMin = 0.30;
S.fixMin = 'Minimum fixation duration (s):';
P.fixRan = 0.20;
S.fixRan = 'Additional random fixation duration (s):';
P.stimDur = c.TrialDurationSeconds;
S.stimDur = 'Stimulus duration (s):';
P.RewardDur = 1;
S.RewardDur = 'Cumulative following per reward (s):';
P.iti = 0.5;
S.iti = 'Inter-trial interval (s):';
P.blank_iti = 0.5;
S.blank_iti = 'Additional error interval (s):';
P.eyeRadius = 2.5;
S.eyeRadius = 'Gaze-indicator radius (deg):';
P.eyeIntensity = 40;
S.eyeIntensity = 'Gaze-indicator intensity:';
P.showEye = 0;
S.showEye = 'Show gaze indicator?';
end
