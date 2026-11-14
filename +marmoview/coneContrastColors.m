function colors = coneContrastColors(calibrationSource,coneAxis,axisScale,coneSelection)
% CONECONTRASTCOLORS Calculate symmetric RGB endpoints about a neutral background.
%
% colors = marmoview.coneContrastColors(result,[-1 1 0],1)
% colors = marmoview.coneContrastColors('ConeMath2026_results.mat',[-1 1 0],1)
%
% coneAxis is expressed in the order given by result.ConePeaks. For the
% ConeMath2026 human preset [558 530 420], [-1 1 0] is the M-L axis.
%
% When the calibration contains measured gamma curves (GammaDeviceInput /
% GammaLinearOutput), device codes and realized values use those curves
% and colors.Encoded*RGB255 hold software-encoded framebuffer values
% (GammaSource 'empirical'). Otherwise the power-law exponent is used
% (GammaSource 'power-law'). *RGB255 fields are always linear.

if nargin < 3 || isempty(axisScale)
    axisScale = 1;
end
if nargin < 4
    coneSelection = [];
end
if ~isscalar(axisScale) || ~isfinite(axisScale) || axisScale < 0 || axisScale > 1
    error('coneContrastColors:AxisScale', ...
        'axisScale must be a finite scalar in [0,1].');
end

[result,sourceName] = loadCalibrationResult(calibrationSource,coneSelection);
requiredFields = {'ConePeaks','RGB_to_Cones','Cones_to_RGB','BackgroundRGB'};
for ii = 1:numel(requiredFields)
    if ~isfield(result,requiredFields{ii})
        error('coneContrastColors:MissingField', ...
            'Calibration is missing result.%s.',requiredFields{ii});
    end
end

conePeaks = double(result.ConePeaks(:));
coneAxis = double(coneAxis(:));
if numel(coneAxis) ~= numel(conePeaks) || any(~isfinite(coneAxis)) || ...
        ~any(abs(coneAxis) > 0)
    error('coneContrastColors:ConeAxis', ...
        'coneAxis must contain one finite value per calibrated cone class.');
end

backgroundRGB = double(result.BackgroundRGB(:));
rgbToCones = double(result.RGB_to_Cones);
conesToRGB = double(result.Cones_to_RGB);
if numel(backgroundRGB) ~= 3 || any(backgroundRGB <= 0) || ...
        any(backgroundRGB >= 1)
    error('coneContrastColors:BackgroundRGB', ...
        'BackgroundRGB must contain three values strictly between zero and one.');
end

backgroundExcitation = rgbToCones*backgroundRGB;
rgbDirection = conesToRGB*(backgroundExcitation.*coneAxis);
positiveLimit = oneSidedLimit(backgroundRGB,rgbDirection);
negativeLimit = oneSidedLimit(backgroundRGB,-rgbDirection);
symmetricLimit = min(positiveLimit,negativeLimit);
axisAmplitude = axisScale*symmetricLimit;

negativeLinearRGB = backgroundRGB-axisAmplitude*rgbDirection;
positiveLinearRGB = backgroundRGB+axisAmplitude*rgbDirection;
negativeLinearRGB = checkGamut(negativeLinearRGB,'negative');
positiveLinearRGB = checkGamut(positiveLinearRGB,'positive');

negativeExcitation = rgbToCones*negativeLinearRGB;
positiveExcitation = rgbToCones*positiveLinearRGB;
negativeConeContrast = (negativeExcitation-backgroundExcitation)./backgroundExcitation;
positiveConeContrast = (positiveExcitation-backgroundExcitation)./backgroundExcitation;

colors = struct();
colors.Source = sourceName;
colors.ConePeaks = conePeaks';
colors.ConeAxis = coneAxis';
colors.BackgroundLinearRGB = backgroundRGB';
colors.NegativeLinearRGB = negativeLinearRGB';
colors.PositiveLinearRGB = positiveLinearRGB';
colors.BackgroundRGB255 = 255*backgroundRGB';
colors.NegativeRGB255 = 255*negativeLinearRGB';
colors.PositiveRGB255 = 255*positiveLinearRGB';
colors.RGBDirectionPerUnitAxis = rgbDirection';
colors.PositiveAxisLimit = positiveLimit;
colors.NegativeAxisLimit = negativeLimit;
colors.MaximumSymmetricAxisAmplitude = symmetricLimit;
colors.AxisScale = axisScale;
colors.AxisAmplitude = axisAmplitude;
colors.NegativeConeContrast = negativeConeContrast';
colors.PositiveConeContrast = positiveConeContrast';
colors.RuntimeColorRange = 255;
if isfield(result,'GammaExponent')
    colors.GammaExponent = double(result.GammaExponent(:))';
end
if isfield(result,'InverseGamma')
    colors.InverseGamma = double(result.InverseGamma(:))';
elseif isfield(colors,'GammaExponent')
    colors.InverseGamma = 1 ./ colors.GammaExponent;
end
if isfield(result,'BitDepth')
    colors.BitDepth = double(result.BitDepth);
else
    colors.BitDepth = 8;
end
if hasEmpiricalGamma(result)
    % Measured gamma curves take precedence over any fitted exponent.
    calibration = struct( ...
        'GammaDeviceInput',{gammaCurves(result.GammaDeviceInput)}, ...
        'GammaLinearOutput',{gammaCurves(result.GammaLinearOutput)}, ...
        'BitDepth',colors.BitDepth,'GammaApplication','software-encoded');
    realization = marmoview.realizeCalibratedRGB(calibration, ...
        [backgroundRGB'; negativeLinearRGB'; positiveLinearRGB']);
    colors.GammaSource = 'empirical';
    colors.BackgroundDeviceCodes = realization.DeviceCodes(1,:);
    colors.NegativeDeviceCodes = realization.DeviceCodes(2,:);
    colors.PositiveDeviceCodes = realization.DeviceCodes(3,:);
    colors.EncodedBackgroundRGB255 = realization.FramebufferRGB255(1,:);
    colors.EncodedNegativeRGB255 = realization.FramebufferRGB255(2,:);
    colors.EncodedPositiveRGB255 = realization.FramebufferRGB255(3,:);
    colors.RealizedBackgroundLinearRGB = realization.RealizedLinearRGB(1,:);
    colors.RealizedNegativeLinearRGB = realization.RealizedLinearRGB(2,:);
    colors.RealizedPositiveLinearRGB = realization.RealizedLinearRGB(3,:);
    realizedBackgroundExcitation = rgbToCones* ...
        colors.RealizedBackgroundLinearRGB(:);
    colors.RealizedNegativeConeContrast = ((rgbToCones* ...
        colors.RealizedNegativeLinearRGB(:))-realizedBackgroundExcitation)' ./ ...
        realizedBackgroundExcitation';
    colors.RealizedPositiveConeContrast = ((rgbToCones* ...
        colors.RealizedPositiveLinearRGB(:))-realizedBackgroundExcitation)' ./ ...
        realizedBackgroundExcitation';
elseif isfield(colors,'GammaExponent') && isfield(colors,'InverseGamma')
    colors.GammaSource = 'power-law';
    maximumCode = 2^colors.BitDepth-1;
    colors.NegativeDeviceCodes = round(maximumCode* ...
        negativeLinearRGB'.^colors.InverseGamma);
    colors.PositiveDeviceCodes = round(maximumCode* ...
        positiveLinearRGB'.^colors.InverseGamma);
    colors.BackgroundDeviceCodes = round(maximumCode* ...
        backgroundRGB'.^colors.InverseGamma);
    colors.RealizedNegativeLinearRGB = ...
        (colors.NegativeDeviceCodes/maximumCode).^colors.GammaExponent;
    colors.RealizedPositiveLinearRGB = ...
        (colors.PositiveDeviceCodes/maximumCode).^colors.GammaExponent;
    colors.RealizedBackgroundLinearRGB = ...
        (colors.BackgroundDeviceCodes/maximumCode).^colors.GammaExponent;
    realizedBackgroundExcitation = rgbToCones* ...
        colors.RealizedBackgroundLinearRGB(:);
    colors.RealizedNegativeConeContrast = ((rgbToCones* ...
        colors.RealizedNegativeLinearRGB(:))-realizedBackgroundExcitation)' ./ ...
        realizedBackgroundExcitation';
    colors.RealizedPositiveConeContrast = ((rgbToCones* ...
        colors.RealizedPositiveLinearRGB(:))-realizedBackgroundExcitation)' ./ ...
        realizedBackgroundExcitation';
end
metadataFields = {'SchemaVersion','Warning','PhenotypeID','MonitorTarget', ...
    'GammaMethod','GammaApplication','PsychtoolboxColorRange', ...
    'ConditionNumber'};
for ii = 1:numel(metadataFields)
    if isfield(result,metadataFields{ii})
        colors.(metadataFields{ii}) = result.(metadataFields{ii});
    end
end
end


function limit = oneSidedLimit(backgroundRGB,direction)
limits = inf(3,1);
positive = direction > 0;
negative = direction < 0;
limits(positive) = (1-backgroundRGB(positive))./direction(positive);
limits(negative) = backgroundRGB(negative)./(-direction(negative));
limit = min(limits);
if ~isfinite(limit) || limit <= 0
    error('coneContrastColors:GamutLimit', ...
        'The requested cone axis has no positive in-gamut extent.');
end
end


function rgb = checkGamut(rgb,label)
tolerance = 1e-10;
if any(rgb < -tolerance) || any(rgb > 1+tolerance)
    error('coneContrastColors:OutOfGamut', ...
        'The %s endpoint is outside the monitor gamut.',label);
end
rgb(abs(rgb) < tolerance) = 0;
rgb(abs(rgb-1) < tolerance) = 1;
end


function [result,sourceName] = loadCalibrationResult(calibrationSource,coneSelection)
if isstruct(calibrationSource)
    result = selectResult(calibrationSource,coneSelection);
    sourceName = '<MATLAB struct>';
    return
end

sourceName = char(calibrationSource);
if ~exist(sourceName,'file')
    error('coneContrastColors:CalibrationMissing', ...
        'Cone calibration file not found: %s',sourceName);
end
[~,~,extension] = fileparts(sourceName);
if strcmpi(extension,'.json')
    loaded = jsondecode(fileread(sourceName));
    result = selectJsonResult(loaded,coneSelection);
else
    loaded = load(sourceName);
    result = selectResult(loaded,coneSelection);
end
end


function result = selectResult(value,coneSelection)
if isfield(value,'result')
    result = value.result;
    if numel(result) > 1
        requireSelection(coneSelection);
        match = arrayfun(@(x) matchesSelection(x,coneSelection),result);
        if nnz(match) ~= 1
            error('coneContrastColors:PhenotypeSelection', ...
                'Explicit cone selection matched %d calibration results.',nnz(match));
        end
        result = result(match);
    end
elseif isfield(value,'results')
    candidates = value.results;
    requireSelection(coneSelection);
    match = arrayfun(@(x) matchesSelection(x,coneSelection),candidates);
    if nnz(match) ~= 1
        error('coneContrastColors:PhenotypeSelection', ...
            'Explicit cone selection matched %d calibration results.',nnz(match));
    end
    result = candidates(match);
elseif all(isfield(value,{'ConePeaks','RGB_to_Cones','Cones_to_RGB','BackgroundRGB'}))
    result = value;
else
    error('coneContrastColors:CalibrationFormat', ...
        'Expected a ConeMath result struct, result variable, or results array.');
end
validateConeResult(result);
end


function result = selectJsonResult(value,coneSelection)
if isfield(value,'ConePeaksNm') && isfield(value,'RGBToCones')
    result = coneMathManifestResult(value);
    validateConeResult(result);
    return
end
if isfield(value,'phenotypes')
    candidates = value.phenotypes;
    requireSelection(coneSelection);
    match = arrayfun(@(x) matchesJsonSelection(x,coneSelection),candidates);
    if nnz(match) ~= 1
        error('coneContrastColors:PhenotypeSelection', ...
            'Explicit cone selection matched %d JSON results.',nnz(match));
    end
    value = candidates(match);
end
requiredFields = {'cone_peaks_nm','rgb_to_cones','background_linear_rgb'};
if ~all(isfield(value,requiredFields))
    error('coneContrastColors:CalibrationFormat', ...
        'JSON manifest is missing cone peaks, RGB-to-cones, or background RGB.');
end

result = struct();
result.ConePeaks = double(value.cone_peaks_nm(:))';
result.RGB_to_Cones = double(value.rgb_to_cones);
result.Cones_to_RGB = pinv(result.RGB_to_Cones);
result.BackgroundRGB = double(value.background_linear_rgb(:));
if isfield(value,'assumed_gamma')
    result.GammaExponent = repmat(double(value.assumed_gamma),1,3);
    result.InverseGamma = 1 ./ result.GammaExponent;
end
jsonMap = {
    'schema_version','SchemaVersion'
    'warning','Warning'
    'phenotype_id','PhenotypeID'
    'monitor_target','MonitorTarget'
    'gamma_method','GammaMethod'
    'gamma_application','GammaApplication'
    'psychtoolbox_color_range','PsychtoolboxColorRange'
    'bit_depth','BitDepth'
    'condition_number','ConditionNumber'
    };
for ii = 1:size(jsonMap,1)
    if isfield(value,jsonMap{ii,1})
        result.(jsonMap{ii,2}) = value.(jsonMap{ii,1});
    end
end
validateConeResult(result);
end


function result = coneMathManifestResult(value)
% ConeMath2026 manifest.json (PascalCase fields).
result = struct();
result.ConePeaks = double(value.ConePeaksNm(:))';
result.RGB_to_Cones = double(value.RGBToCones);
result.Cones_to_RGB = pinv(result.RGB_to_Cones);
result.BackgroundRGB = double(value.BackgroundRGB(:));
map = {'GammaDeviceInput','GammaDeviceInput'; 'GammaLinearOutput','GammaLinearOutput'
    'BitDepth','BitDepth'; 'GammaApplication','GammaApplication'
    'SchemaVersion','SchemaVersion'; 'PhenotypeID','PhenotypeID'
    'MonitorIdentifier','MonitorTarget'};
for ii = 1:size(map,1)
    if isfield(value,map{ii,1})
        result.(map{ii,2}) = value.(map{ii,1});
    end
end
if isfield(value,'Validation') && isfield(value.Validation,'ConditionNumber')
    result.ConditionNumber = value.Validation.ConditionNumber;
end
end


function tf = hasEmpiricalGamma(result)
tf = isfield(result,'GammaDeviceInput') && isfield(result,'GammaLinearOutput') && ...
    ~isempty(result.GammaDeviceInput) && ~isempty(result.GammaLinearOutput);
end


function curves = gammaCurves(value)
% Accept a three-cell array, an N-by-3 matrix, or a 3-by-N matrix.
if iscell(value)
    curves = reshape(cellfun(@(x) double(x(:)),value,'UniformOutput',false),1,3);
elseif size(value,2) == 3
    curves = arrayfun(@(ii) double(value(:,ii)),1:3,'UniformOutput',false);
else
    curves = arrayfun(@(ii) double(value(ii,:))',1:3,'UniformOutput',false);
end
end


function requireSelection(selection)
if isempty(selection)
    error('coneContrastColors:ExplicitSelectionRequired', ...
        ['A multi-phenotype calibration requires an explicit cone-peak ' ...
        'vector or phenotype identifier.']);
end
end


function tf = matchesSelection(candidate,selection)
if isnumeric(selection)
    tf = isequal(double(candidate.ConePeaks(:))',double(selection(:))');
else
    tf = false;
    names = {'PhenotypeName','PhenotypeID'};
    for ii = 1:numel(names)
        if isfield(candidate,names{ii})
            tf = strcmpi(char(candidate.(names{ii})),char(selection));
            if tf
                return
            end
        end
    end
end
end


function tf = matchesJsonSelection(candidate,selection)
if isnumeric(selection)
    tf = isfield(candidate,'cone_peaks_nm') && ...
        isequal(double(candidate.cone_peaks_nm(:))',double(selection(:))');
else
    tf = isfield(candidate,'phenotype_id') && ...
        strcmpi(char(candidate.phenotype_id),char(selection));
end
end


function validateConeResult(result)
peaks = double(result.ConePeaks(:));
matrix = double(result.RGB_to_Cones);
if isempty(peaks) || size(matrix,1) ~= numel(peaks) || size(matrix,2) ~= 3
    error('coneContrastColors:ConeMatrixShape', ...
        'RGB_to_Cones must have one row per explicitly selected cone class.');
end
end
