function outputFile = build_proxy_human_isoluminant_calibration(sourceRoot,outputFile)
% BUILD_PROXY_HUMAN_ISOLUMINANT_CALIBRATION Create a proxy-only test contract.

if nargin < 1 || isempty(sourceRoot)
    sourceRoot = fullfile('C:\Users\Declan\Documents\2026', ...
        'ConeColorMath','Dummy_DELL_P2419HC_proxy');
end
taskRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin < 2 || isempty(outputFile)
    outputFile = fullfile(taskRoot,'SupportData','ConeCalibration', ...
        'HumanIsoluminantML','ConeMath2026_proxy_results.mat');
end

manifestFile = fullfile(sourceRoot,'exports','human_T_558_530_420', ...
    'manifest.json');
spectraFile = fullfile(sourceRoot,'proxy_primary_spectra.tsv');
if ~exist(manifestFile,'file') || ~exist(spectraFile,'file')
    error('build_proxy_human_isoluminant_calibration:MissingSource', ...
        'Proxy manifest or primary spectra are missing under %s.',sourceRoot);
end
manifest = jsondecode(fileread(manifestFile));
spectra = readtable(spectraFile,'FileType','text','Delimiter','\t');
wavelengths = double(spectra.WavelengthNm(:));
primarySpectra = double(spectra{:,{'Red','Green','Blue'}});

cieFile = which('T_xyz1931.mat');
if isempty(cieFile)
    error('build_proxy_human_isoluminant_calibration:CIE1931Missing', ...
        ['T_xyz1931.mat was not found. Add Psychtoolbox, including its ' ...
        'PsychColorimetricData directory, to the MATLAB path.']);
end
cie = load(cieFile);
cieWavelengths = cie.S_xyz1931(1) + ...
    (0:cie.S_xyz1931(3)-1)'*cie.S_xyz1931(2);
yBar = interp1(cieWavelengths,double(cie.T_xyz1931(2,:))', ...
    wavelengths,'linear',0);
yWeights = zeros(1,3);
for channel = 1:3
    yWeights(channel) = trapz(wavelengths, ...
        yBar.*primarySpectra(:,channel));
end

gammaExponent = double(manifest.assumed_gamma);
device = linspace(0,1,4097)';
result = struct();
result.SchemaVersion = 'ConeMath2026-PROXY-TEST-2.1';
result.Warning = ['NOT FOR EXPERIMENTS: P2419H spectral proxy, assumed ' ...
    'gamma, and computed CIE 1931 Y weights.'];
result.IsDummyCalibration = true;
result.PhenotypeName = char(manifest.phenotype_id);
result.ConePeaks = double(manifest.cone_peaks_nm(:))';
result.RGB_to_Cones = double(manifest.rgb_to_cones);
result.Cones_to_RGB = pinv(result.RGB_to_Cones);
result.BackgroundRGB = double(manifest.background_linear_rgb(:))';
result.PhotopicLuminanceRGB = yWeights;
result.CIE1931YBar = yBar;
result.PhotopicLuminanceConvention = ...
    ['CIE 1931 2-degree y-bar integrated against the P2419H proxy ' ...
    'energy-calibrated primary spectra'];
result.PhotopicLuminanceSource = struct('File',cieFile, ...
    'SpectralProxyFile',spectraFile);
result.GammaDeviceInput = {device device device};
result.GammaLinearOutput = {device.^gammaExponent device.^gammaExponent ...
    device.^gammaExponent};
result.GammaExponent = repmat(gammaExponent,1,3);
result.InverseGamma = 1./result.GammaExponent;
result.GammaApplication = 'software-encoded';
result.BitDepth = double(manifest.bit_depth);
result.MonitorIdentifier = char(manifest.monitor_target);
result.CalibrationDate = 'PROXY';
if isfield(manifest,'spectral_file_sha256')
    result.CalibrationChecksumSHA256 = char(manifest.spectral_file_sha256);
end

outputDirectory = fileparts(outputFile);
if ~exist(outputDirectory,'dir')
    mkdir(outputDirectory);
end
save(outputFile,'result');
fprintf('Wrote proxy-only human isoluminant calibration:\n  %s\n',outputFile);
fprintf('This file is for software and visual testing only.\n');
end
