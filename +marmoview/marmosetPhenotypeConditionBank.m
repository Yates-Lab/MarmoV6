function bank = marmosetPhenotypeConditionBank(calibrationSource,options)
% MARMOSETPHENOTYPECONDITIONBANK Build contrast-matched diagnostic and control fields.
%
% bank = marmoview.marmosetPhenotypeConditionBank(calibrationSource,options)
%
% All conditions share one background. The three pigment nulls are matched
% in contrast: each is scaled so that its largest non-silenced ML Weber
% contrast equals MatchedContrast. Achromatic fields use the same Weber
% contrast (times AchromaticContrastScales) in every candidate cone.
%
% Options:
%   BackgroundMode                'optimized' (default) or 'exported'
%   MinimumBackgroundLuminanceCdM2  Luminance floor (60)
%   BackgroundChannelBounds       ([0.1 0.9]); BackgroundStepSize (0.01)
%   MatchedContrastFraction       Fraction of the matched gamut limit (0.95)
%   ContrastLevels                Scales applied to MatchedContrast (1)
%   AchromaticContrastScales      Achromatic Weber contrast / MatchedContrast (1)
%   NullSweepOffsetsNm            Extra null peaks around each pigment (0)
%   SilentLeakageTolerance, SilentLeakageWarning, RelativeLeakageTolerance
%   ExpectedMonitorIdentifier, MaximumCalibrationAgeDays, RequireModel (true)

if nargin < 2 || isempty(options)
    options = struct();
end
options = setDefault(options,'BackgroundMode','optimized');
options = setDefault(options,'MinimumBackgroundLuminanceCdM2',60);
options = setDefault(options,'BackgroundChannelBounds',[0.1 0.9]);
options = setDefault(options,'BackgroundStepSize',0.01);
options = setDefault(options,'MatchedContrastFraction',0.95);
options = setDefault(options,'ContrastLevels',1);
options = setDefault(options,'AchromaticContrastScales',1);
options = setDefault(options,'NullSweepOffsetsNm',0);
options = setDefault(options,'SilentLeakageTolerance',0.005);
options = setDefault(options,'SilentLeakageWarning',0.002);
options = setDefault(options,'RelativeLeakageTolerance',0.10);
options = setDefault(options,'ExpectedMonitorIdentifier','');
options = setDefault(options,'MaximumCalibrationAgeDays',Inf);
options = setDefault(options,'RequireModel',true);

levels = double(options.ContrastLevels(:)');
if isempty(levels) || any(~isfinite(levels)) || any(levels <= 0) || any(levels > 1)
    error('marmosetPhenotypeConditionBank:ContrastLevels', ...
        'ContrastLevels must contain values in (0,1].');
end
achromaticScales = double(options.AchromaticContrastScales(:)');
if isempty(achromaticScales) || any(~isfinite(achromaticScales)) || ...
        any(achromaticScales <= 0)
    error('marmosetPhenotypeConditionBank:AchromaticContrastScales', ...
        'AchromaticContrastScales must be positive.');
end
fraction = double(options.MatchedContrastFraction);
if ~isscalar(fraction) || ~isfinite(fraction) || fraction <= 0 || fraction > 1
    error('marmosetPhenotypeConditionBank:MatchedContrastFraction', ...
        'MatchedContrastFraction must be a scalar in (0,1].');
end
sweepOffsets = double(options.NullSweepOffsetsNm(:)');
if ~any(sweepOffsets == 0) || any(~isfinite(sweepOffsets)) || ...
        any(abs(sweepOffsets) > 6)
    error('marmosetPhenotypeConditionBank:NullSweepOffsetsNm', ...
        'NullSweepOffsetsNm must include 0 and lie within +/-6 nm.');
end

loadOptions = struct('AllowDummy',false, ...
    'ExpectedMonitorIdentifier',options.ExpectedMonitorIdentifier, ...
    'MaximumCalibrationAgeDays',options.MaximumCalibrationAgeDays, ...
    'RequireModel',options.RequireModel);
exported = marmoview.loadCandidateConeCalibration(calibrationSource,loadOptions);
selectionOptions = struct( ...
    'MinimumLuminanceCdM2',options.MinimumBackgroundLuminanceCdM2, ...
    'ChannelBounds',options.BackgroundChannelBounds, ...
    'StepSize',options.BackgroundStepSize, ...
    'MatchedContrastFraction',fraction, ...
    'SilentLeakageTolerance',options.SilentLeakageTolerance, ...
    'RelativeLeakageTolerance',options.RelativeLeakageTolerance, ...
    'AchromaticContrastScale',max(achromaticScales));
switch lower(char(options.BackgroundMode))
    case 'optimized'
    case 'exported'
        selectionOptions.FixedBackgroundLinearRGB = exported.BackgroundLinearRGB;
    otherwise
        error('marmosetPhenotypeConditionBank:BackgroundMode', ...
            'BackgroundMode must be optimized or exported.');
end
selection = marmoview.optimizeMarmosetBackground(exported,selectionOptions);
background = selection.BackgroundLinearRGB;
matchedContrast = fraction*selection.MatchedContrastLimit;

loadOptions.BackgroundLinearRGB = background;
calibration = marmoview.loadCandidateConeCalibration(calibrationSource,loadOptions);
nullOptions = struct( ...
    'SilentLeakageTolerance',options.SilentLeakageTolerance, ...
    'SilentLeakageWarning',options.SilentLeakageWarning, ...
    'RelativeLeakageTolerance',options.RelativeLeakageTolerance, ...
    'TargetContrast',matchedContrast, ...
    'BackgroundLinearRGB',background, ...
    'ExpectedMonitorIdentifier',options.ExpectedMonitorIdentifier, ...
    'MaximumCalibrationAgeDays',options.MaximumCalibrationAgeDays, ...
    'RequireModel',options.RequireModel);

conditions = struct([]);
for peak = [543 556 563]
    for offset = sweepOffsets
        nullOptions.AllowOffNominalPeak = offset ~= 0;
        for level = levels
            item = marmoview.marmosetPigmentNull(calibrationSource, ...
                peak+offset,level,nullOptions);
            conditions = appendCondition(conditions,item);
        end
    end
end
for scale = achromaticScales
    conditions = appendCondition(conditions,makeAchromatic(calibration, ...
        scale,scale*matchedContrast));
end
conditions = appendCondition(conditions,makeCatch(calibration));

bank = struct();
bank.SchemaVersion = 'MarmosetPhenotypeConditionBank-2.0';
bank.CalibrationSource = calibration.CalibrationSource;
bank.CalibrationChecksum = calibration.CalibrationChecksum;
bank.MonitorIdentifier = calibration.MonitorIdentifier;
bank.CalibrationDate = calibration.CalibrationDate;
bank.ConePeaksNm = calibration.CandidateConePeaksNm(:)';
bank.RodPeakNm = calibration.RodPeakNm;
bank.NomogramModel = calibration.NomogramModel;
bank.BackgroundMode = lower(char(options.BackgroundMode));
bank.BackgroundLinearRGB = background;
bank.BackgroundLuminanceCdM2 = calibration.BackgroundLuminanceCdM2;
bank.BackgroundSelection = selection;
bank.MatchedContrast = matchedContrast;
bank.MatchedContrastFraction = fraction;
bank.ContrastLevels = levels;
bank.AchromaticContrastScales = achromaticScales;
bank.NullSweepOffsetsNm = sweepOffsets;
bank.SilentLeakageTolerance = options.SilentLeakageTolerance;
bank.RelativeLeakageTolerance = options.RelativeLeakageTolerance;
bank.Conditions = conditions;
end


function condition = makeAchromatic(calibration,scale,contrast)
b = calibration.BackgroundLinearRGB(:);
limit = min((1-b)./b);
if contrast > min(1,limit)*(1+1e-12)
    error('marmosetPhenotypeConditionBank:AchromaticGamut', ...
        'Achromatic contrast %.4g exceeds the %.4g gamut limit.', ...
        contrast,min(1,limit));
end
condition = makeControl(calibration,sprintf('achromatic_scale_%g',scale), ...
    'achromatic',b*(1-contrast),b*(1+contrast),scale,limit,1);
condition.Amplitude = contrast;
condition.MatchedContrast = contrast;
end


function condition = makeCatch(calibration)
b = calibration.BackgroundLinearRGB(:);
condition = makeControl(calibration,'catch','catch',b,b,0,0,0);
condition.Amplitude = 0;
condition.MatchedContrast = 0;
end


function condition = makeControl(calibration,id,type,negativeRGB,positiveRGB, ...
        scale,positiveLimit,negativeLimit)
T = calibration.CandidateRGBToCones;
b = calibration.BackgroundLinearRGB(:);
backgroundDevice = marmoview.realizeCalibratedRGB(calibration,b');
negativeDevice = marmoview.realizeCalibratedRGB(calibration,negativeRGB');
positiveDevice = marmoview.realizeCalibratedRGB(calibration,positiveRGB');
endpoints = [negativeRGB positiveRGB];
realizedBackground = backgroundDevice.RealizedLinearRGB(:);
realizedEndpoints = [negativeDevice.RealizedLinearRGB(:) ...
    positiveDevice.RealizedLinearRGB(:)];

condition = marmoview.marmosetPigmentNullTemplate(calibration);
condition.ConditionID = id;
condition.ConditionType = type;
condition.NegativeLinearRGB = negativeRGB';
condition.PositiveLinearRGB = positiveRGB';
condition.BackgroundDeviceCodes = backgroundDevice.DeviceCodes;
condition.NegativeDeviceCodes = negativeDevice.DeviceCodes;
condition.PositiveDeviceCodes = positiveDevice.DeviceCodes;
condition.BackgroundFramebufferRGB255 = backgroundDevice.FramebufferRGB255;
condition.NegativeFramebufferRGB255 = negativeDevice.FramebufferRGB255;
condition.PositiveFramebufferRGB255 = positiveDevice.FramebufferRGB255;
condition.RealizedBackgroundLinearRGB = backgroundDevice.RealizedLinearRGB;
condition.RealizedNegativeLinearRGB = negativeDevice.RealizedLinearRGB;
condition.RealizedPositiveLinearRGB = positiveDevice.RealizedLinearRGB;
condition.RequestedConeContrast = weber(T,endpoints,b)';
condition.RealizedConeContrast = weber(T,realizedEndpoints,realizedBackground)';
if all(isfinite(calibration.RodRGBToExcitation))
    condition.RequestedRodContrast = ...
        weber(calibration.RodRGBToExcitation,endpoints,b)';
    condition.RealizedRodContrast = weber(calibration.RodRGBToExcitation, ...
        realizedEndpoints,realizedBackground)';
end
condition.MaximumSilentLeakage = 0;
condition.SignalContrast = min(max(abs(condition.RealizedConeContrast(:,1:3)),[],2));
condition.PositiveGamutLimit = positiveLimit;
condition.NegativeGamutLimit = negativeLimit;
condition.MaximumSymmetricAmplitude = min(positiveLimit,negativeLimit);
condition.AxisScale = scale;
condition.ValidationPass = true;
end


function contrast = weber(rows,endpoints,background)
backgroundExcitation = rows*background;
contrast = ((rows*endpoints)-backgroundExcitation)./backgroundExcitation;
end


function conditions = appendCondition(conditions,item)
if isempty(conditions)
    conditions = item;
else
    conditions(end+1) = item;
end
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
