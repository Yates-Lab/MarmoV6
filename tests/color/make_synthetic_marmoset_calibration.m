function calibration = make_synthetic_marmoset_calibration(bitDepth)
% MAKE_SYNTHETIC_MARMOSET_CALIBRATION Mathematical-test fixture only.
%
% Gaussian monitor primaries; CandidateRGBToCones and the rod row are
% generated from the exported pigment model so the loader's model check
% applies. Default bit depth 16 isolates the mathematics from quantization.

if nargin < 1 || isempty(bitDepth)
    bitDepth = 16;
end
wavelengths = (380:780)';
primary = @(peak,width) exp(-0.5*((wavelengths-peak)/width).^2);
spectra = [primary(610,14) primary(545,22) primary(455,12)];
spectra = spectra./sum(spectra,1).*[0.9 1.0 0.6];
model = struct('Nomogram','Baylor, Nunn and Schnapf 1987', ...
    'Convention','quantal nomogram converted for energy-calibrated SPD', ...
    'SpecificDensityPerMicron',0.015,'OuterSegmentLengthMicrons',20, ...
    'PreRetinalTransmittance',[]);
peaks = [563 556 543 423];

calibration = struct();
calibration.SchemaVersion = 'SYNTHETIC-TEST-2.2';
calibration.CandidateConePeaksNm = peaks;
calibration.CandidateRGBToCones = ...
    marmoview.pigmentFundamentals(model,wavelengths,peaks)*spectra;
calibration.BackgroundLinearRGB = [0.5 0.5 0.5];
calibration.CandidateBackgroundExcitations = ...
    calibration.CandidateRGBToCones*calibration.BackgroundLinearRGB(:);
calibration.WavelengthsNm = wavelengths;
calibration.PrimarySpectra = spectra;
calibration.NomogramModel = model;
calibration.RodPeakNm = 500;
calibration.RodRGBToExcitation = ...
    marmoview.pigmentFundamentals(model,wavelengths,500)*spectra;
calibration.PhotopicLuminanceCdM2PerLinearRGB = [45 160 15];
device = linspace(0,1,4097)';
calibration.GammaDeviceInput = {device device device};
calibration.GammaLinearOutput = {device.^2.2 device.^2.2 device.^2.2};
calibration.BitDepth = bitDepth;
calibration.GammaApplication = 'software-encoded';
calibration.CalibrationChecksumSHA256 = ...
    'SYNTHETIC_TEST_FIXTURE_NOT_AN_EXPERIMENTAL_CALIBRATION';
calibration.MonitorIdentifier = 'SYNTHETIC_TEST_MONITOR';
calibration.CalibrationDate = '2000-01-01';
calibration.IsDummyCalibration = false;
end
