function F = pigmentFundamentals(model,wavelengthsNm,peaksNm,opticalDensityScale)
% PIGMENTFUNDAMENTALS Energy-unit pigment sensitivities matching ConeMath2026.
%
% F = marmoview.pigmentFundamentals(model,wavelengthsNm,peaksNm)
% F = marmoview.pigmentFundamentals(model,wavelengthsNm,peaksNm,odScale)
%
% model is calibration.NomogramModel exported by ConeMath2026 (schema 2.2+).
% Rows of F are normalized to a peak of one, as in ConeMath2026, so
% F*PrimarySpectra reproduces CandidateRGBToCones. odScale multiplies the
% exported axial optical density and is used for robustness analysis.

if nargin < 4 || isempty(opticalDensityScale)
    opticalDensityScale = 1;
end
wavelengthsNm = double(wavelengthsNm(:));
peaksNm = double(peaksNm(:))';
if any(~isfinite(peaksNm)) || any(peaksNm < 350) || any(peaksNm > 700)
    error('pigmentFundamentals:Peak', ...
        'Pigment peaks must be finite wavelengths between 350 and 700 nm.');
end

coefficients = [-5.2734 -87.403 1228.4 -3346.3 -5070.3 30881 -31607];
wavelengthMicrons = wavelengthsNm/1000;
F = zeros(numel(peaksNm),numel(wavelengthsNm));
for ii = 1:numel(peaksNm)
    x = log10((1./wavelengthMicrons)*peaksNm(ii)/561)';
    logSensitivity = coefficients(1) + coefficients(2).*x + ...
        coefficients(3).*x.^2 + coefficients(4).*x.^3 + ...
        coefficients(5).*x.^4 + coefficients(6).*x.^5 + ...
        coefficients(7).*x.^6;
    F(ii,:) = 10.^logSensitivity;
end
F = F./max(F,[],2);

opticalDensity = opticalDensityScale*model.SpecificDensityPerMicron* ...
    model.OuterSegmentLengthMicrons;
if opticalDensity > 0
    F = 1 - 10.^(-opticalDensity.*F);
end
F = F.*wavelengthsNm';

if isfield(model,'PreRetinalTransmittance') && ...
        ~isempty(model.PreRetinalTransmittance)
    transmittance = double(model.PreRetinalTransmittance(:));
    exportWavelengths = (380:780)';
    if numel(transmittance) ~= numel(exportWavelengths)
        error('pigmentFundamentals:Transmittance', ...
            'PreRetinalTransmittance must be sampled at 380:780 nm.');
    end
    F = F.*interp1(exportWavelengths,transmittance,wavelengthsNm, ...
        'linear',0)';
end
F = F./max(F,[],2);
end
