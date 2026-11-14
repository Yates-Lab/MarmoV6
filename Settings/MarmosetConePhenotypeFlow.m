function [S,P] = MarmosetConePhenotypeFlow
% MARMOSETCONEPHENOTYPEFLOW Two-field rivalry test of candidate-pigment nulls.

S = MarmoViewRigSettings;
S.MarmoViewVersion = '6';
S.protocol = 'MarmosetConePhenotypeFlow';
S.protocol_class = 'protocols.PR_MarmosetConePhenotypeFlow';
S.protocolTitle = 'Marmoset Cone Null Rivalry';
S.TimeSensitive = 1:3;

taskRoot = fileparts(fileparts(mfilename('fullpath')));
calibrationFolder = fullfile(taskRoot,'SupportData','ConeCalibration', ...
    'MarmosetCandidateCones');
defaultCalibration = fullfile(calibrationFolder,'ConeMath2026_runtime.mat');
if isfield(S,'marmosetCandidateCalibrationFile') && ...
        ~isempty(S.marmosetCandidateCalibrationFile)
    calibrationFile = S.marmosetCandidateCalibrationFile;
else
    calibrationFile = defaultCalibration;
end
if ~exist(calibrationFile,'file')
    error('MarmosetConePhenotypeFlow:CalibrationUnavailable', ...
        ['Experimental candidate-cone calibration is unavailable. Expected: ' ...
        '%s. Dummy calibration fallback is prohibited.'],calibrationFile);
end

% Fixed experimental configuration: retained in S and saved with every file.
c = struct();
c.CalibrationFile = calibrationFile;
c.ExpectedMonitorIdentifier = S.monitor;
c.MaximumCalibrationAgeDays = 365;
c.RequireSpectralVerification = true;
c.SpectralVerificationFile = fullfile(calibrationFolder, ...
    'marmoset_spectral_verification.mat');
% Background: 'optimized' lowers the ML-cone background (mostly green) to
% raise the matched null contrast, down to the luminance floor. On the 2018
% LG calibration: 7.8% at 108 cd/m2, 11.4% at 75, 14.4% at 60, 17.7% at 50.
% Lower luminance risks rod intrusion; see the README.
c.BackgroundMode = 'optimized';
c.MinimumBackgroundLuminanceCdM2 = 60;
c.BackgroundChannelBounds = [0.1 0.9];
c.MatchedContrastFraction = 0.95;
c.ContrastLevels = 1;
c.AchromaticContrastScales = 1;
c.NullSweepOffsetsNm = 0;
c.SilentLeakageTolerance = 0.005;
c.SilentLeakageWarning = 0.002;
c.RelativeLeakageTolerance = 0.10;
% Trials.
c.RepeatsPerPair = 12;
c.TrajectoryPairCount = 6;
c.IncludeDetectionPairs = true;
c.IncludeAchromaticPairs = false;
c.CatchTrialFraction = 0.10;
c.RandomSeed = 260829;
c.TrialDurationSeconds = 5;
c.OnsetExclusionSeconds = 0.30;
% Dots: square, non-anti-aliased, drawn with blending off (exact colours).
c.DotSizeDeg = 0.15;
c.DotCount = 1100; % total over both fields
c.DotType = 0;
c.FlowExpansionSpeed = 0.10;
c.DotLifetimeFrames = 30;
c.MinimumDotSeparationDeg = 0.25;
c.DotPlacementAttempts = 50;
% Flow-centre walks.
c.FlowCentreSpeedDegPerSecond = 6;
c.FlowCentreMaximumEccentricityDeg = 7;
c.FlowCentreFilterTimeConstantSeconds = 0.3;
c.FlowCentreStartOffsetDeg = 2.5;
c.MinimumCentreSeparationDeg = 4;
c.MaximumCentreVelocityCorrelation = 0.2;
c.FollowWindowRadiusDeg = 2;
% Validity and choice scoring.
c.MinimumValidEyeSamples = round(S.frameRate);
c.MaximumEyeGapSeconds = 0.3;
c.MaximumLongFrameFraction = 0.05;
c.MinimumAnalysisDurationSeconds = 1;
c.ChoiceMinimumFraction = 0.25;
c.ChoiceMargin = 0.10;
S.marmosetConfig = c;

screenHalfHeightDeg = S.screenRect(4)/2/S.pixPerDeg;
if c.FlowCentreMaximumEccentricityDeg + c.FollowWindowRadiusDeg > screenHalfHeightDeg
    error('MarmosetConePhenotypeFlow:ScreenSize', ...
        ['Flow centres (%.1f deg) plus the following window (%.1f deg) ' ...
        'exceed the %.1f deg screen half-height.'], ...
        c.FlowCentreMaximumEccentricityDeg,c.FollowWindowRadiusDeg, ...
        screenHalfHeightDeg);
end

bankOptions = struct( ...
    'BackgroundMode',c.BackgroundMode, ...
    'MinimumBackgroundLuminanceCdM2',c.MinimumBackgroundLuminanceCdM2, ...
    'BackgroundChannelBounds',c.BackgroundChannelBounds, ...
    'MatchedContrastFraction',c.MatchedContrastFraction, ...
    'ContrastLevels',c.ContrastLevels, ...
    'AchromaticContrastScales',c.AchromaticContrastScales, ...
    'NullSweepOffsetsNm',c.NullSweepOffsetsNm, ...
    'SilentLeakageTolerance',c.SilentLeakageTolerance, ...
    'SilentLeakageWarning',c.SilentLeakageWarning, ...
    'RelativeLeakageTolerance',c.RelativeLeakageTolerance, ...
    'ExpectedMonitorIdentifier',c.ExpectedMonitorIdentifier, ...
    'MaximumCalibrationAgeDays',c.MaximumCalibrationAgeDays, ...
    'RequireModel',true);
S.marmosetConditionBank = marmoview.marmosetPhenotypeConditionBank( ...
    calibrationFile,bankOptions);
bank = S.marmosetConditionBank;
S.marmosetConfig.CalibrationChecksum = bank.CalibrationChecksum;
S.marmosetConfig.PhotopicBackgroundLinearRGB = bank.BackgroundLinearRGB;
S.marmosetConfig.BackgroundLuminanceCdM2 = bank.BackgroundLuminanceCdM2;

if ~strcmpi(bank.Conditions(1).GammaApplication,'software-encoded')
    error('MarmosetConePhenotypeFlow:GammaPolicy', ...
        ['The protocol requires software-encoded empirical gamma. ' ...
        'PTB gamma-LUT installation is not yet enabled.']);
end
S.gammaApplication = 'software-encoded'; % openScreen adds no further gamma

if c.RequireSpectralVerification
    if ~exist(c.SpectralVerificationFile,'file')
        error('MarmosetConePhenotypeFlow:SpectralVerificationMissing', ...
            ['Measure the patches from marmoview.marmosetVerificationPatches ' ...
            'and save them as "measurements" in %s, or set ' ...
            'RequireSpectralVerification = false for a non-experimental pilot.'], ...
            c.SpectralVerificationFile);
    end
    loaded = load(c.SpectralVerificationFile,'measurements');
    S.marmosetSpectralVerification = ...
        marmoview.verifyMarmosetConditionSpectra(bank,loaded.measurements);
    if ~S.marmosetSpectralVerification.Pass
        failed = S.marmosetSpectralVerification.Conditions( ...
            ~[S.marmosetSpectralVerification.Conditions.Pass]);
        error('MarmosetConePhenotypeFlow:SpectralVerificationFailed', ...
            'Measured spectra fail verification for: %s', ...
            strjoin({failed.ConditionID},', '));
    end
end

trajectoryOptions = struct( ...
    'FrameRate',S.frameRate, ...
    'StimulusDuration',c.TrialDurationSeconds, ...
    'TrajectoryPairCount',c.TrajectoryPairCount, ...
    'RandomSeed',c.RandomSeed, ...
    'SpeedDegPerSecond',c.FlowCentreSpeedDegPerSecond, ...
    'MaximumEccentricityDeg',c.FlowCentreMaximumEccentricityDeg, ...
    'FilterTimeConstantSeconds',c.FlowCentreFilterTimeConstantSeconds, ...
    'StartOffsetDeg',c.FlowCentreStartOffsetDeg, ...
    'MinimumCentreSeparationDeg',c.MinimumCentreSeparationDeg, ...
    'MaximumVelocityCorrelation',c.MaximumCentreVelocityCorrelation);
S.marmosetTrajectoryBank = ...
    marmoview.makeMarmosetFlowTrajectoryBank(trajectoryOptions);

planOptions = struct( ...
    'RepeatsPerPair',c.RepeatsPerPair, ...
    'TrajectoryPairCount',c.TrajectoryPairCount, ...
    'RandomSeed',c.RandomSeed, ...
    'RewardAmount',3, ...
    'CatchTrialFraction',c.CatchTrialFraction, ...
    'IncludeDetectionPairs',c.IncludeDetectionPairs, ...
    'IncludeAchromaticPairs',c.IncludeAchromaticPairs);
S.marmosetTrialPlan = marmoview.makeMarmosetPhenotypeTrialPlan(bank,planOptions);
S.finish = size(S.marmosetTrialPlan.Rows,1);
S.bgColour = bank.Conditions(1).BackgroundFramebufferRGB255;

% GUI-editable values remain numeric scalars.
P.RepeatUntilCorrect = 0;
S.RepeatUntilCorrect = 'Repeat incomplete trials? (0 or 1):';
P.PreserveTrialOrder = 1;
S.PreserveTrialOrder = 'Preserve constrained trial order (must remain 1):';
P.rewardNumber = 3;
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
P.startDur = 4;
S.startDur = 'Time to acquire fixation (s):';
P.flashFrameLength = 30;
S.flashFrameLength = 'Fixation flash duration (frames):';
P.fixGrace = 0.05;
S.fixGrace = 'Fixation grace period (s):';
P.fixMin = 0.20;
S.fixMin = 'Minimum fixation duration (s):';
P.fixRan = 0.10;
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
