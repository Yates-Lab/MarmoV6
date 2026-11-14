function condition = marmosetPigmentNull(calibrationSource,nullPeakNm,axisScale,options)
% MARMOSETPIGMENTNULL Make an S- and candidate-pigment-silent RGB axis.
%
% condition = marmoview.marmosetPigmentNull(calibrationSource,nullPeakNm,axisScale)
% condition = marmoview.marmosetPigmentNull(...,options)
%
% Without options.TargetContrast the amplitude is axisScale times the
% largest symmetric in-gamut amplitude. With TargetContrast it is
% axisScale*TargetContrast, expressed as the largest requested Weber
% contrast among the non-silenced ML candidates; this is how conditions
% are matched in contrast.
%
% Options:
%   SilentLeakageTolerance      Absolute realized leakage limit (0.005)
%   SilentLeakageWarning        Absolute realized leakage warning (0.002)
%   RelativeLeakageTolerance    Leakage / realized signal limit (0.10)
%   TargetContrast              Matched ML contrast (default [])
%   BackgroundLinearRGB         Background override (default: exported)
%   ExpectedMonitorIdentifier, MaximumCalibrationAgeDays, RequireModel
%   AllowOffNominalPeak         Permit nulls between 530 and 575 nm (false)
%   RobustnessPeakOffsetsNm     Silenced-pigment peak errors ([-2 -1 1 2])
%   RobustnessOpticalDensityScales   ([0.5 1.5])
%   RobustnessSPeakOffsetsNm    ([-5 5])

if nargin < 3 || isempty(axisScale)
    axisScale = 1;
end
if nargin < 4 || isempty(options)
    options = struct();
end
options = setDefault(options,'SilentLeakageTolerance',0.005);
options = setDefault(options,'SilentLeakageWarning',0.002);
options = setDefault(options,'RelativeLeakageTolerance',0.10);
options = setDefault(options,'TargetContrast',[]);
options = setDefault(options,'BackgroundLinearRGB',[]);
options = setDefault(options,'ExpectedMonitorIdentifier','');
options = setDefault(options,'MaximumCalibrationAgeDays',Inf);
options = setDefault(options,'RequireModel',false);
options = setDefault(options,'AllowOffNominalPeak',false);
options = setDefault(options,'RobustnessPeakOffsetsNm',[-2 -1 1 2]);
options = setDefault(options,'RobustnessOpticalDensityScales',[0.5 1.5]);
options = setDefault(options,'RobustnessSPeakOffsetsNm',[-5 5]);

if ~isscalar(axisScale) || ~isfinite(axisScale) || ...
        axisScale < 0 || axisScale > 1
    error('marmosetPigmentNull:AxisScale', ...
        'axisScale must be a finite scalar in [0,1].');
end
nominalNulls = [543 556 563];
if ~isscalar(nullPeakNm) || ~isfinite(nullPeakNm)
    error('marmosetPigmentNull:NullPeak','nullPeakNm must be a finite scalar.');
end
isNominal = ismember(nullPeakNm,nominalNulls);
if ~isNominal && ~(logical(options.AllowOffNominalPeak) && ...
        nullPeakNm >= 530 && nullPeakNm <= 575)
    error('marmosetPigmentNull:NullPeak', ...
        'nullPeakNm must be 543, 556, or 563.');
end
if ~isempty(options.TargetContrast) && (~isscalar(options.TargetContrast) || ...
        ~isfinite(options.TargetContrast) || options.TargetContrast <= 0)
    error('marmosetPigmentNull:TargetContrast', ...
        'TargetContrast must be a positive finite scalar.');
end

loadOptions = struct('AllowDummy',false, ...
    'ExpectedMonitorIdentifier',options.ExpectedMonitorIdentifier, ...
    'MaximumCalibrationAgeDays',options.MaximumCalibrationAgeDays, ...
    'RequireModel',logical(options.RequireModel) || ~isNominal, ...
    'BackgroundLinearRGB',options.BackgroundLinearRGB);
calibration = marmoview.loadCandidateConeCalibration(calibrationSource,loadOptions);
peaks = calibration.CandidateConePeaksNm(:)';
T = calibration.CandidateRGBToCones;
b = calibration.BackgroundLinearRGB(:);
e0 = calibration.CandidateBackgroundExcitations(:);
sIndex = find(peaks == 423,1);

% Off-nominal nulls borrow the sign/normalization set of the nearest pigment.
[~,nearest] = min(abs(nominalNulls-nullPeakNm));
referencePeak = nominalNulls(nearest);
if isNominal
    nullRow = T(peaks == nullPeakNm,:);
    silentIndices = [sIndex find(peaks == nullPeakNm,1)];
else
    nullRow = marmoview.pigmentFundamentals(calibration.NomogramModel, ...
        calibration.WavelengthsNm,nullPeakNm)*calibration.PrimarySpectra;
    silentIndices = sIndex;
end
A = [T(sIndex,:); nullRow];
tolerance = 1e-10*max(1,norm(A,'fro'));
if rank(A,tolerance) ~= 2
    error('marmosetPigmentNull:Rank', ...
        'The S-plus-target silent-constraint matrix must have rank two.');
end
d = null(A);
if size(d,2) ~= 1 || norm(A*d) > tolerance
    error('marmosetPigmentNull:Nullspace', ...
        'Silent constraints did not produce one valid RGB direction.');
end

mlIndices = find(peaks ~= 423 & peaks ~= referencePeak);
unitContrast = (T*d)./e0;
normalizer = max(abs(unitContrast(mlIndices)));
if ~isfinite(normalizer) || normalizer <= tolerance
    error('marmosetPigmentNull:NoModulation', ...
        'The null direction does not modulate a non-silenced ML pigment.');
end
d = d/normalizer;
unitContrast = (T*d)./e0;
signIndex = mlIndices(find(peaks(mlIndices) == max(peaks(mlIndices)),1));
if unitContrast(signIndex) < 0
    d = -d;
    unitContrast = -unitContrast;
end

positiveLimit = gamutLimit(b,d);
negativeLimit = gamutLimit(b,-d);
symmetricLimit = min(positiveLimit,negativeLimit);
if isempty(options.TargetContrast)
    amplitude = axisScale*symmetricLimit;
else
    amplitude = axisScale*options.TargetContrast;
    if amplitude > symmetricLimit*(1+1e-12)
        error('marmosetPigmentNull:TargetContrast', ...
            ['Requested contrast %.4g exceeds the %.4g symmetric gamut limit ' ...
            'of null%g on this background.'],amplitude,symmetricLimit,nullPeakNm);
    end
end
negativeRGB = cleanGamut(b-amplitude*d);
positiveRGB = cleanGamut(b+amplitude*d);
endpoints = [negativeRGB positiveRGB];
requestedContrast = ((T*endpoints)-e0)./e0;

backgroundDevice = marmoview.realizeCalibratedRGB(calibration,b');
negativeDevice = marmoview.realizeCalibratedRGB(calibration,negativeRGB');
positiveDevice = marmoview.realizeCalibratedRGB(calibration,positiveRGB');
realizedBackground = backgroundDevice.RealizedLinearRGB(:);
realizedEndpoints = [negativeDevice.RealizedLinearRGB(:) ...
    positiveDevice.RealizedLinearRGB(:)];
realizedContrast = weber(T,realizedEndpoints,realizedBackground);
nullPigmentRequested = weber(nullRow,endpoints,b);
nullPigmentRealized = weber(nullRow,realizedEndpoints,realizedBackground);

silentRealized = [realizedContrast(sIndex,:); nullPigmentRealized];
maximumSilentLeakage = max(abs(silentRealized),[],'all');
signalContrast = min(max(abs(realizedContrast(mlIndices,:)),[],1));
relativeLeakage = maximumSilentLeakage/max(eps,signalContrast);
if amplitude > 0
    if maximumSilentLeakage > options.SilentLeakageTolerance
        error('marmosetPigmentNull:SilentLeakage', ...
            'Realized silent-cone leakage %.6g exceeds tolerance %.6g.', ...
            maximumSilentLeakage,options.SilentLeakageTolerance);
    end
    if relativeLeakage > options.RelativeLeakageTolerance
        error('marmosetPigmentNull:RelativeLeakage', ...
            ['Realized silent-cone leakage is %.3g of the %.4g signal ' ...
            '(limit %.3g). Raise the contrast or the display bit depth.'], ...
            relativeLeakage,signalContrast,options.RelativeLeakageTolerance);
    end
    if maximumSilentLeakage > options.SilentLeakageWarning
        warning('marmosetPigmentNull:SilentLeakageWarning', ...
            'Realized silent-cone leakage for null%g is %.6g.', ...
            nullPeakNm,maximumSilentLeakage);
    end
end

condition = marmoview.marmosetPigmentNullTemplate(calibration);
condition.ConditionID = sprintf('null%g_scale_%g',nullPeakNm,axisScale);
condition.ConditionType = 'pigment-null';
condition.NullPeakNm = nullPeakNm;
condition.NominalNullPeakNm = referencePeak;
condition.NegativeLinearRGB = negativeRGB';
condition.PositiveLinearRGB = positiveRGB';
condition = addRealization(condition,backgroundDevice,negativeDevice,positiveDevice);
condition.RequestedConeContrast = requestedContrast';
condition.RealizedConeContrast = realizedContrast';
condition.RequestedNullPigmentContrast = nullPigmentRequested';
condition.RealizedNullPigmentContrast = nullPigmentRealized';
condition = addRodContrast(condition,calibration,endpoints,b, ...
    realizedEndpoints,realizedBackground);
condition.SilentConeIndices = silentIndices;
condition.MaximumSilentLeakage = maximumSilentLeakage;
condition.SignalContrast = signalContrast;
condition.RelativeSilentLeakage = relativeLeakage;
condition.PositiveGamutLimit = positiveLimit;
condition.NegativeGamutLimit = negativeLimit;
condition.MaximumSymmetricAmplitude = symmetricLimit;
condition.AxisScale = axisScale;
condition.Amplitude = amplitude;
condition.MatchedContrast = amplitude;
condition.ValidationPass = true;
condition.UnitRGBDirection = d';
condition.UnitCandidateConeContrast = unitContrast';
condition.ModelRobustness = robustness(calibration,nullPeakNm, ...
    realizedEndpoints,realizedBackground,signalContrast,options);
end


function condition = addRealization(condition,background,negative,positive)
condition.BackgroundDeviceCodes = background.DeviceCodes;
condition.NegativeDeviceCodes = negative.DeviceCodes;
condition.PositiveDeviceCodes = positive.DeviceCodes;
condition.BackgroundFramebufferRGB255 = background.FramebufferRGB255;
condition.NegativeFramebufferRGB255 = negative.FramebufferRGB255;
condition.PositiveFramebufferRGB255 = positive.FramebufferRGB255;
condition.RealizedBackgroundLinearRGB = background.RealizedLinearRGB;
condition.RealizedNegativeLinearRGB = negative.RealizedLinearRGB;
condition.RealizedPositiveLinearRGB = positive.RealizedLinearRGB;
end


function condition = addRodContrast(condition,calibration,endpoints,b, ...
        realizedEndpoints,realizedBackground)
if all(isfinite(calibration.RodRGBToExcitation))
    condition.RequestedRodContrast = ...
        weber(calibration.RodRGBToExcitation,endpoints,b)';
    condition.RealizedRodContrast = weber(calibration.RodRGBToExcitation, ...
        realizedEndpoints,realizedBackground)';
end
end


function report = robustness(calibration,nullPeakNm,realizedEndpoints, ...
        realizedBackground,signalContrast,options)
report = struct('Available',calibration.ModelAvailable, ...
    'PeakOffsetsNm',options.RobustnessPeakOffsetsNm, ...
    'PeakOffsetLeakage',[], ...
    'OpticalDensityScales',options.RobustnessOpticalDensityScales, ...
    'OpticalDensityLeakage',[], ...
    'SPeakOffsetsNm',options.RobustnessSPeakOffsetsNm, ...
    'SPeakOffsetLeakage',[], ...
    'MaximumModelLeakage',NaN,'MaximumModelLeakageRatio',NaN);
if ~calibration.ModelAvailable
    return
end
model = calibration.NomogramModel;
wavelengths = calibration.WavelengthsNm;
P = calibration.PrimarySpectra;
leak = @(row) max(abs(weber(row,realizedEndpoints,realizedBackground)));
report.PeakOffsetLeakage = arrayfun(@(offset) leak( ...
    marmoview.pigmentFundamentals(model,wavelengths,nullPeakNm+offset)*P), ...
    options.RobustnessPeakOffsetsNm);
report.OpticalDensityLeakage = arrayfun(@(scale) leak( ...
    marmoview.pigmentFundamentals(model,wavelengths,nullPeakNm,scale)*P), ...
    options.RobustnessOpticalDensityScales);
report.SPeakOffsetLeakage = arrayfun(@(offset) leak( ...
    marmoview.pigmentFundamentals(model,wavelengths,423+offset)*P), ...
    options.RobustnessSPeakOffsetsNm);
report.MaximumModelLeakage = max([report.PeakOffsetLeakage ...
    report.OpticalDensityLeakage report.SPeakOffsetLeakage]);
report.MaximumModelLeakageRatio = ...
    report.MaximumModelLeakage/max(eps,signalContrast);
end


function contrast = weber(rows,endpoints,background)
backgroundExcitation = rows*background;
contrast = ((rows*endpoints)-backgroundExcitation)./backgroundExcitation;
end


function limit = gamutLimit(background,direction)
limits = inf(3,1);
positive = direction > 1e-14;
negative = direction < -1e-14;
limits(positive) = (1-background(positive))./direction(positive);
limits(negative) = background(negative)./(-direction(negative));
limit = min(limits);
if ~isfinite(limit) || limit < 0
    error('marmosetPigmentNull:Gamut', ...
        'No positive in-gamut amplitude exists for the null direction.');
end
end


function rgb = cleanGamut(rgb)
tolerance = 1e-10;
if any(rgb < -tolerance) || any(rgb > 1+tolerance)
    error('marmosetPigmentNull:Gamut','Calculated endpoint is outside gamut.');
end
rgb = min(max(rgb,0),1);
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
