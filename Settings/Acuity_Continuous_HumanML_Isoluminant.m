function [S,P] = Acuity_Continuous_HumanML_Isoluminant
% Human M-L pilot constrained to silence S cones and CIE 1931 luminance.

[S,P] = Acuity_Continuous;
S.protocol = 'Acuity_Continuous_HumanML_Isoluminant';
S.protocol_class = 'protocols.PR_Acuity_Continuous';
S.protocolTitle = 'Human isoluminant M-L Acuity Track';

taskRoot = fileparts(fileparts(mfilename('fullpath')));
defaultCalibration = fullfile(taskRoot,'SupportData','ConeCalibration', ...
    'HumanIsoluminantML','ConeMath2026_results.mat');
if ~isfield(S,'humanConeCalibrationFile') || ...
        isempty(S.humanConeCalibrationFile)
    if isfield(S,'coneCalibrationFile') && ~isempty(S.coneCalibrationFile)
        S.humanConeCalibrationFile = S.coneCalibrationFile;
    else
        S.humanConeCalibrationFile = defaultCalibration;
    end
end
if ~exist(S.humanConeCalibrationFile,'file')
    error('Acuity_Continuous_HumanML_Isoluminant:CalibrationMissing', ...
        ['Human LMS+CIE-Y calibration not found: %s. Export a measured ' ...
        'human result with ConeMath2026 before running this protocol.'], ...
        S.humanConeCalibrationFile);
end

S.coneAxisScale = 1;
if ~isfield(S,'humanIsoluminanceAdjustment')
    S.humanIsoluminanceAdjustment = 0;
end
allowDummy = isfield(S,'allowDummyHumanConeCalibration') && ...
    logical(S.allowDummyHumanConeCalibration);
solverOptions = struct( ...
    'BehavioralCIEYPerMContrast',S.humanIsoluminanceAdjustment, ...
    'AllowDummy',allowDummy);
if allowDummy
    % Proxy 8-bit quantization is expected to exceed experimental leakage
    % tolerances. Keep a hard bound so gross calibration errors still stop.
    solverOptions.LeakageWarning = 0.005;
    solverOptions.LeakageError = 0.02;
end
S.coneColor = marmoview.humanIsoluminantML( ...
    S.humanConeCalibrationFile,S.coneAxisScale,solverOptions);
S.coneCalibrationIsDummy = isfield(S.coneColor,'SchemaVersion') && ...
    contains(upper(char(S.coneColor.SchemaVersion)),'PROXY');
if S.coneCalibrationIsDummy
    S.protocolTitle = 'PROXY Human isoluminant M-L';
    warning('Acuity_Continuous_HumanML_Isoluminant:ProxyCalibration', ...
        ['Running with P2419H proxy spectra and assumed gamma. ' ...
        'Software/visual testing only; do not collect experimental data.']);
end
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
end
