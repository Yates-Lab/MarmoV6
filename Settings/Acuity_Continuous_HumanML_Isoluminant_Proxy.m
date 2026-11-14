function [S,P] = Acuity_Continuous_HumanML_Isoluminant_Proxy
% Explicit proxy-only human M-L isoluminance visual/software test.

[S,P] = Acuity_Continuous;
S.protocol = 'Acuity_Continuous_HumanML_Isoluminant_Proxy';
S.protocol_class = 'protocols.PR_Acuity_Continuous';
S.protocolTitle = 'PROXY Human isoluminant M-L';

taskRoot = fileparts(fileparts(mfilename('fullpath')));
proxyCalibration = fullfile(taskRoot,'SupportData','ConeCalibration', ...
    'HumanIsoluminantML','ConeMath2026_proxy_results.mat');
if ~exist(proxyCalibration,'file')
    error('Acuity_Continuous_HumanML_Isoluminant_Proxy:CalibrationMissing', ...
        ['Proxy calibration not found: %s. Run ' ...
        'build_proxy_human_isoluminant_calibration first.'],proxyCalibration);
end

S.humanConeCalibrationFile = proxyCalibration;
S.allowDummyHumanConeCalibration = true;
S.coneCalibrationIsDummy = true;
S.coneCalibrationPurpose = 'SOFTWARE/VISUAL TESTING ONLY - NOT EXPERIMENTAL';
S.humanIsoluminanceAdjustment = 0;
S.coneAxisScale = 1;
solverOptions = struct( ...
    'AllowDummy',true, ...
    'BehavioralCIEYPerMContrast',S.humanIsoluminanceAdjustment, ...
    'LeakageWarning',0.005, ...
    'LeakageError',0.02);
S.coneColor = marmoview.humanIsoluminantML( ...
    proxyCalibration,S.coneAxisScale,solverOptions);
S.coneAxisLabel = S.coneColor.ConeAxisLabel;
S.coneAxis = S.coneColor.ConeAxis;
S.gammaApplication = S.coneColor.GammaApplication;
S.bgColour = S.coneColor.BackgroundRGB255;

P.bkgd = mean(S.bgColour);
P.mode = 1;
P.balancedDots = 1;
P.dotContrast = 1;
P.normalizeDotRms = 0;
P.showEye = 0;

warning('Acuity_Continuous_HumanML_Isoluminant_Proxy:ProxyCalibration', ...
    ['P2419H proxy spectra and assumed gamma are active. ' ...
    'Do not collect experimental data with this protocol.']);
end
