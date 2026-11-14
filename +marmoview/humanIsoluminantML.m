function colors = humanIsoluminantML(calibrationSource,axisScale,options)
% HUMANISOLUMINANTML Solve an S-silent, CIE-Y-silent human M-L direction.

if nargin < 2 || isempty(axisScale)
    axisScale = 1;
end
if nargin < 3 || isempty(options)
    options = struct();
end
options = setDefault(options,'AllowDummy',false);
options = setDefault(options,'LeakageWarning',0.002);
options = setDefault(options,'LeakageError',0.005);
options = setDefault(options,'BehavioralCIEYPerMContrast',0);
if ~isscalar(axisScale) || ~isfinite(axisScale) || ...
        axisScale < 0 || axisScale > 1
    error('humanIsoluminantML:AxisScale', ...
        'axisScale must be a finite scalar in [0,1].');
end
if ~isscalar(options.BehavioralCIEYPerMContrast) || ...
        ~isfinite(options.BehavioralCIEYPerMContrast)
    error('humanIsoluminantML:BehavioralAdjustment', ...
        'BehavioralCIEYPerMContrast must be a finite scalar.');
end

calibration = marmoview.loadHumanConeCalibration(calibrationSource,options);
T = calibration.RGBToCones;
background = calibration.BackgroundLinearRGB(:);
yRow = calibration.PhotopicLuminanceRGB(:)';
backgroundExcitation = T*background;
backgroundY = yRow*background;

constraints = [T(3,:); yRow; T(2,:)];
if rank(constraints,1e-12*norm(constraints)) ~= 3
    error('humanIsoluminantML:ConstraintRank', ...
        'The S, CIE-Y, and M constraints are not independent.');
end
targets = [0; options.BehavioralCIEYPerMContrast*backgroundY; ...
    backgroundExcitation(2)];
rgbDirection = constraints\targets;
coneDirection = (T*rgbDirection)./backgroundExcitation;

positiveLimit = oneSidedLimit(background,rgbDirection);
negativeLimit = oneSidedLimit(background,-rgbDirection);
symmetricLimit = min(positiveLimit,negativeLimit);
amplitude = axisScale*symmetricLimit;
requestedLinear = [background'; ...
    (background-amplitude*rgbDirection)'; ...
    (background+amplitude*rgbDirection)'];
realized = marmoview.realizeCalibratedRGB(calibration,requestedLinear);

requestedExcitation = (T*requestedLinear')';
requestedContrast = (requestedExcitation-backgroundExcitation') ./ ...
    backgroundExcitation';
realizedBackgroundExcitation = T*realized.RealizedLinearRGB(1,:)';
realizedExcitation = (T*realized.RealizedLinearRGB')';
realizedContrast = (realizedExcitation-realizedBackgroundExcitation') ./ ...
    realizedBackgroundExcitation';
requestedYContrast = ((requestedLinear*yRow')-backgroundY)/backgroundY;
realizedBackgroundY = yRow*realized.RealizedLinearRGB(1,:)';
realizedYContrast = ((realized.RealizedLinearRGB*yRow')- ...
    realizedBackgroundY)/realizedBackgroundY;
realizedYResidual = realizedYContrast(2:3) - ...
    options.BehavioralCIEYPerMContrast*realizedContrast(2:3,2);
maximumLeakage = max(abs([realizedContrast(2:3,3); ...
    realizedYResidual]));
if maximumLeakage > options.LeakageError
    error('humanIsoluminantML:RealizedLeakage', ...
        ['Realized S/Y leakage %.6g exceeds the hard tolerance %.6g. ' ...
        'Use a finer framebuffer or reduce contrast.'], ...
        maximumLeakage,options.LeakageError);
elseif maximumLeakage > options.LeakageWarning
    warning('humanIsoluminantML:RealizedLeakage', ...
        'Realized S/Y leakage %.6g exceeds warning tolerance %.6g.', ...
        maximumLeakage,options.LeakageWarning);
end

colors = struct();
colors.Source = calibration.Source;
colors.ConePeaks = calibration.ConePeaks(:)';
colors.ConeAxis = coneDirection(:)';
colors.ConeAxisLabel = 'M-L, S-silent and CIE-Y-isoluminant';
colors.BackgroundLinearRGB = requestedLinear(1,:);
colors.NegativeLinearRGB = requestedLinear(2,:);
colors.PositiveLinearRGB = requestedLinear(3,:);
colors.BackgroundRGB255 = realized.FramebufferRGB255(1,:);
colors.NegativeRGB255 = realized.FramebufferRGB255(2,:);
colors.PositiveRGB255 = realized.FramebufferRGB255(3,:);
colors.BackgroundDeviceCodes = realized.DeviceCodes(1,:);
colors.NegativeDeviceCodes = realized.DeviceCodes(2,:);
colors.PositiveDeviceCodes = realized.DeviceCodes(3,:);
colors.RealizedBackgroundLinearRGB = realized.RealizedLinearRGB(1,:);
colors.RealizedNegativeLinearRGB = realized.RealizedLinearRGB(2,:);
colors.RealizedPositiveLinearRGB = realized.RealizedLinearRGB(3,:);
colors.NegativeConeContrast = requestedContrast(2,:);
colors.PositiveConeContrast = requestedContrast(3,:);
colors.RealizedNegativeConeContrast = realizedContrast(2,:);
colors.RealizedPositiveConeContrast = realizedContrast(3,:);
colors.NegativeCIEYContrast = requestedYContrast(2);
colors.PositiveCIEYContrast = requestedYContrast(3);
colors.RealizedNegativeCIEYContrast = realizedYContrast(2);
colors.RealizedPositiveCIEYContrast = realizedYContrast(3);
colors.RealizedNegativeCIEYResidual = realizedYResidual(1);
colors.RealizedPositiveCIEYResidual = realizedYResidual(2);
colors.PhotopicLuminanceRGB = yRow;
colors.PhotopicLuminanceConvention = ...
    calibration.PhotopicLuminanceConvention;
colors.BehavioralCIEYPerMContrast = ...
    options.BehavioralCIEYPerMContrast;
if isfield(calibration,'PhotopicLuminanceSource')
    colors.PhotopicLuminanceSource = calibration.PhotopicLuminanceSource;
end
colors.RGBDirectionPerUnitAxis = rgbDirection(:)';
colors.PositiveAxisLimit = positiveLimit;
colors.NegativeAxisLimit = negativeLimit;
colors.MaximumSymmetricAxisAmplitude = symmetricLimit;
colors.AxisScale = axisScale;
colors.AxisAmplitude = amplitude;
colors.RealizedMaximumSilentLeakage = maximumLeakage;
colors.SilentLeakageWarning = options.LeakageWarning;
colors.SilentLeakageError = options.LeakageError;
colors.BitDepth = calibration.BitDepth;
colors.GammaApplication = calibration.GammaApplication;
colors.DeviceEncodedEndpoints = true;
colors.RequiresUnitDotContrast = true;
colors.RuntimeColorRange = 255;
metadataFields = {'SchemaVersion','PhenotypeName','MonitorIdentifier', ...
    'CalibrationDate','CalibrationChecksumSHA256'};
for ii = 1:numel(metadataFields)
    if isfield(calibration,metadataFields{ii})
        colors.(metadataFields{ii}) = calibration.(metadataFields{ii});
    end
end
end


function limit = oneSidedLimit(background,direction)
limits = inf(3,1);
limits(direction > 0) = (1-background(direction > 0))./direction(direction > 0);
limits(direction < 0) = background(direction < 0)./(-direction(direction < 0));
limit = min(limits);
if ~isfinite(limit) || limit <= 0
    error('humanIsoluminantML:GamutLimit', ...
        'The isoluminant direction has no in-gamut extent.');
end
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
