function calibration = loadHumanConeCalibration(calibrationSource,options)
% LOADHUMANCONECALIBRATION Load the human LMS plus CIE-Y runtime contract.

if nargin < 2 || isempty(options)
    options = struct();
end
options = setDefault(options,'AllowDummy',false);

[raw,sourceName] = readSource(calibrationSource);
raw = unwrapResult(raw);

calibration = struct();
calibration.ConePeaks = double(requireField(raw, ...
    {'ConePeaks','cone_peaks_nm'},'cone peaks'));
calibration.RGBToCones = double(requireField(raw, ...
    {'RGB_to_Cones','RGBToCones','rgb_to_cones'},'RGB-to-cones matrix'));
calibration.BackgroundLinearRGB = double(requireField(raw, ...
    {'BackgroundRGB','BackgroundLinearRGB','background_linear_rgb'}, ...
    'background linear RGB'));
calibration.PhotopicLuminanceRGB = double(requireField(raw, ...
    {'PhotopicLuminanceRGB','CIEYPrimaryWeights','photopic_luminance_rgb', ...
    'cie_y_primary_weights'},'CIE 1931 photopic luminance row'));
calibration.PhotopicLuminanceConvention = char(requireField(raw, ...
    {'PhotopicLuminanceConvention','photopic_luminance_convention'}, ...
    'photopic luminance convention'));
calibration.GammaDeviceInput = normalizeGamma(requireField(raw, ...
    {'GammaDeviceInput','gamma_device_input'},'empirical gamma device samples'));
calibration.GammaLinearOutput = normalizeGamma(requireField(raw, ...
    {'GammaLinearOutput','gamma_linear_output'},'empirical gamma output samples'));
calibration.BitDepth = double(requireField(raw,{'BitDepth','bit_depth'}, ...
    'framebuffer bit depth'));
calibration.GammaApplication = char(requireField(raw, ...
    {'GammaApplication','gamma_application'},'gamma-application policy'));
calibration.Source = sourceName;
calibration.IsDummyCalibration = detectDummy(raw,sourceName);

optionalFields = {'SchemaVersion','PhenotypeName','MonitorIdentifier', ...
    'CalibrationDate','CalibrationChecksumSHA256','PhotopicLuminanceSource'};
for ii = 1:numel(optionalFields)
    if isfield(raw,optionalFields{ii})
        calibration.(optionalFields{ii}) = raw.(optionalFields{ii});
    end
end
validateCalibration(calibration,options);
end


function [raw,sourceName] = readSource(source)
if isstruct(source)
    raw = source;
    sourceName = '<MATLAB struct>';
    return
end
sourceName = char(source);
if ~exist(sourceName,'file')
    error('loadHumanConeCalibration:Missing', ...
        'Human cone calibration not found: %s',sourceName);
end
[~,~,extension] = fileparts(sourceName);
if strcmpi(extension,'.json')
    raw = jsondecode(fileread(sourceName));
else
    raw = load(sourceName);
end
end


function raw = unwrapResult(raw)
if isfield(raw,'result')
    raw = raw.result;
elseif isfield(raw,'Result')
    raw = raw.Result;
end
if numel(raw) ~= 1
    error('loadHumanConeCalibration:Selection', ...
        'The human calibration source must contain exactly one result.');
end
end


function value = requireField(source,names,label)
for ii = 1:numel(names)
    if isfield(source,names{ii}) && ~isempty(source.(names{ii}))
        value = source.(names{ii});
        return
    end
end
error('loadHumanConeCalibration:MissingMetadata', ...
    'Calibration is missing %s.',label);
end


function curves = normalizeGamma(value)
if iscell(value) && numel(value) == 3
    curves = reshape(cellfun(@(x) double(x(:)),value, ...
        'UniformOutput',false),1,3);
elseif isnumeric(value) && size(value,2) == 3
    curves = arrayfun(@(ii) double(value(:,ii)),1:3,'UniformOutput',false);
elseif isnumeric(value) && size(value,1) == 3
    curves = arrayfun(@(ii) double(value(ii,:))',1:3,'UniformOutput',false);
else
    error('loadHumanConeCalibration:GammaShape', ...
        'Empirical gamma data must contain one curve per RGB primary.');
end
end


function validateCalibration(calibration,options)
if ~isequal(calibration.ConePeaks(:)',[558 530 420])
    error('loadHumanConeCalibration:ConeOrder', ...
        'Human cone rows must be ordered [558 530 420] nm.');
end
if ~isequal(size(calibration.RGBToCones),[3 3]) || ...
        rank(calibration.RGBToCones) < 3
    error('loadHumanConeCalibration:ConeMatrix', ...
        'RGBToCones must be a full-rank 3-by-3 matrix.');
end
background = calibration.BackgroundLinearRGB(:);
if numel(background) ~= 3 || any(~isfinite(background)) || ...
        any(background <= 0) || any(background >= 1)
    error('loadHumanConeCalibration:Background', ...
        'BackgroundLinearRGB must contain three values inside (0,1).');
end
yRow = calibration.PhotopicLuminanceRGB(:)';
if numel(yRow) ~= 3 || any(~isfinite(yRow)) || any(yRow <= 0)
    error('loadHumanConeCalibration:LuminanceRow', ...
        'PhotopicLuminanceRGB must contain three positive primary weights.');
end
if ~isscalar(calibration.BitDepth) || calibration.BitDepth < 1 || ...
        calibration.BitDepth ~= round(calibration.BitDepth)
    error('loadHumanConeCalibration:BitDepth', ...
        'BitDepth must be a positive integer.');
end
if ~strcmpi(calibration.GammaApplication,'software-encoded')
    error('loadHumanConeCalibration:GammaPolicy', ...
        'The isoluminant protocol currently requires software-encoded gamma.');
end
for channel = 1:3
    x = calibration.GammaDeviceInput{channel};
    y = calibration.GammaLinearOutput{channel};
    if numel(x) ~= numel(y) || numel(x) < 2 || ...
            any(diff(x) <= 0) || any(diff(y) < 0) || ...
            x(1) > 1e-9 || x(end) < 1-1e-9 || ...
            y(1) > 1e-6 || y(end) < 1-1e-6
        error('loadHumanConeCalibration:GammaCurve', ...
            'Gamma curves must be monotonic and span zero to one.');
    end
end
if calibration.IsDummyCalibration && ~logical(options.AllowDummy)
    error('loadHumanConeCalibration:DummyCalibration', ...
        'Dummy/proxy calibration is prohibited for experimental use.');
end
end


function tf = detectDummy(raw,sourceName)
textValue = lower(sourceName);
names = {'Warning','warning','CalibrationPurpose','calibration_purpose'};
for ii = 1:numel(names)
    if isfield(raw,names{ii})
        textValue = [textValue ' ' lower(char(raw.(names{ii})))]; %#ok<AGROW>
    end
end
tf = contains(textValue,'dummy') || contains(textValue,'proxy') || ...
    contains(textValue,'not for experiment');
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
