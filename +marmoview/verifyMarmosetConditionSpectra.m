function report = verifyMarmosetConditionSpectra(bank,measurements,options)
% VERIFYMARMOSETCONDITIONSPECTRA Check pigment silence with measured spectra.
%
% report = marmoview.verifyMarmosetConditionSpectra(bank,measurements,options)
%
% measurements is a struct array with fields DeviceCodes (1x3 integer
% framebuffer codes), WavelengthsNm, and Radiance (spectral radiance,
% all measured with the same instrument and sampling). Pigment excitations
% are computed directly from the measured spectra with the bank's pigment
% model, so this checks the whole display chain (gamma, quantization,
% channel additivity, spectral stability) rather than the RGB model.
%
% Options:
%   MeasuredLeakageTolerance          Absolute silent-pigment limit (0.01)
%   MeasuredRelativeLeakageTolerance  Leakage / measured signal limit (0.2)

if nargin < 3 || isempty(options)
    options = struct();
end
options = setDefault(options,'MeasuredLeakageTolerance',0.01);
options = setDefault(options,'MeasuredRelativeLeakageTolerance',0.2);
if ~isfield(bank,'NomogramModel') || isempty(bank.NomogramModel)
    error('verifyMarmosetConditionSpectra:ModelMissing', ...
        'The condition bank lacks the pigment model needed for verification.');
end
peaks = bank.ConePeaksNm;

template = struct('ConditionID','','ConditionType','', ...
    'MeasuredConeContrast',nan(2,4),'MeasuredNullPigmentContrast',nan(2,1), ...
    'MeasuredRodContrast',nan(2,1),'MaximumSilentLeakage',NaN, ...
    'SignalContrast',NaN,'RelativeSilentLeakage',NaN,'Pass',false,'Message','');
results = repmat(template,numel(bank.Conditions),1);
for ii = 1:numel(bank.Conditions)
    condition = bank.Conditions(ii);
    results(ii).ConditionID = condition.ConditionID;
    results(ii).ConditionType = condition.ConditionType;
    try
        background = findSpectrum(measurements,condition.BackgroundDeviceCodes);
        negative = findSpectrum(measurements,condition.NegativeDeviceCodes);
        positive = findSpectrum(measurements,condition.PositiveDeviceCodes);
    catch exception
        results(ii).Message = exception.message;
        continue
    end
    excitation = @(peak,spectrum) marmoview.pigmentFundamentals( ...
        bank.NomogramModel,spectrum.WavelengthsNm,peak)*spectrum.Radiance(:);
    contrast = @(peak) [excitation(peak,negative); excitation(peak,positive)] ...
        ./excitation(peak,background) - 1;
    results(ii).MeasuredConeContrast = cell2mat(arrayfun(contrast,peaks, ...
        'UniformOutput',false));
    if isfield(bank,'RodPeakNm') && isfinite(bank.RodPeakNm)
        results(ii).MeasuredRodContrast = contrast(bank.RodPeakNm);
    end
    switch condition.ConditionType
        case 'pigment-null'
            results(ii).MeasuredNullPigmentContrast = contrast(condition.NullPeakNm);
            silent = [results(ii).MeasuredConeContrast(:,peaks == 423) ...
                results(ii).MeasuredNullPigmentContrast];
            modulated = peaks ~= 423 & peaks ~= condition.NominalNullPeakNm;
            results(ii).MaximumSilentLeakage = max(abs(silent),[],'all');
            results(ii).SignalContrast = min(max(abs( ...
                results(ii).MeasuredConeContrast(:,modulated)),[],2));
            results(ii).RelativeSilentLeakage = results(ii).MaximumSilentLeakage/ ...
                max(eps,results(ii).SignalContrast);
            results(ii).Pass = results(ii).MaximumSilentLeakage <= ...
                options.MeasuredLeakageTolerance && ...
                results(ii).RelativeSilentLeakage <= ...
                options.MeasuredRelativeLeakageTolerance;
        case 'catch'
            results(ii).MaximumSilentLeakage = max(abs( ...
                results(ii).MeasuredConeContrast),[],'all');
            results(ii).Pass = results(ii).MaximumSilentLeakage <= ...
                options.MeasuredLeakageTolerance;
        otherwise
            results(ii).SignalContrast = min(max(abs( ...
                results(ii).MeasuredConeContrast(:,1:3)),[],2));
            results(ii).Pass = results(ii).SignalContrast > 0;
    end
    if ~results(ii).Pass
        results(ii).Message = 'measured leakage exceeds tolerance';
    end
end

report = struct();
report.SchemaVersion = 'MarmosetSpectralVerification-1.0';
report.CalibrationChecksum = bank.CalibrationChecksum;
report.MonitorIdentifier = bank.MonitorIdentifier;
report.Options = options;
report.Conditions = results;
report.Pass = all([results.Pass]);
end


function spectrum = findSpectrum(measurements,codes)
codes = double(codes(:))';
for ii = 1:numel(measurements)
    if isequal(double(measurements(ii).DeviceCodes(:))',codes)
        spectrum = measurements(ii);
        spectrum.WavelengthsNm = double(spectrum.WavelengthsNm(:));
        spectrum.Radiance = double(spectrum.Radiance(:));
        return
    end
end
error('verifyMarmosetConditionSpectra:MissingMeasurement', ...
    'No measurement for device codes %s.',mat2str(codes));
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
