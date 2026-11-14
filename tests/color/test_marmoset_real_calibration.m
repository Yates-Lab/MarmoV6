function test_marmoset_real_calibration(calibrationFile)
% TEST_MARMOSET_REAL_CALIBRATION Build the condition bank from a measured display.
%
% Uses the 2018 LG 24UD58 PR-655 calibration by default (ignoring its age
% and monitor identity, which the experiment itself enforces). Skips when
% ConeMath2026 or the calibration file is unavailable.

if nargin < 1 || isempty(calibrationFile)
    calibrationFile = fullfile('C:\Users\Declan\Documents\2026\ConeColorMath', ...
        'Monitor Calibration 20180907','RowleyYu_2018_LG24UD58_PCpsychToolbox.txt');
end
if exist('ConeMath2026','file') ~= 2 || ~exist(calibrationFile,'file') || ...
        isempty(which('T_xyz1931.mat'))
    fprintf('test_marmoset_real_calibration: skipped (inputs unavailable).\n');
    return
end
warning('off','marmosetPigmentNull:SilentLeakageWarning');
cleanupWarning = onCleanup(@() warning('on','marmosetPigmentNull:SilentLeakageWarning'));
outputRoot = tempname;
cleanup = onCleanup(@() rmdir(outputRoot,'s'));
ConeMath2026([],struct('CalibrationFile',calibrationFile,'OutputRoot',outputRoot, ...
    'BitDepth',8,'LookupSamples',21,'Verbose',false));
runtime = fullfile(outputRoot,'ConeMath2026_runtime.mat');

grey = marmoview.marmosetPhenotypeConditionBank(runtime, ...
    struct('BackgroundMode','exported'));
optimized = marmoview.marmosetPhenotypeConditionBank(runtime, ...
    struct('MinimumBackgroundLuminanceCdM2',60));
assert(abs(grey.BackgroundSelection.MatchedContrastLimit-0.071) < 0.005);
assert(optimized.BackgroundLuminanceCdM2 >= 60);
assert(optimized.MatchedContrast >= 1.8*grey.MatchedContrast);
nulls = optimized.Conditions(strcmp({optimized.Conditions.ConditionType},'pigment-null'));
assert(all([nulls.RelativeSilentLeakage] <= 0.10));
assert(all([nulls.MaximumSilentLeakage] <= 0.005));

fprintf(['test_marmoset_real_calibration: matched contrast %.3f at %.0f cd/m2 ' ...
    '(grey: %.3f at %.0f cd/m2)\n'],optimized.MatchedContrast, ...
    optimized.BackgroundLuminanceCdM2,grey.MatchedContrast,grey.BackgroundLuminanceCdM2);
for condition = optimized.Conditions(:)'
    fprintf('  %-20s realized [563 556 543 423] %s  rod %+.3f  leak %.4f  model leak %.4f\n', ...
        condition.ConditionID,mat2str(round(condition.RealizedConeContrast(2,:),3)), ...
        condition.RealizedRodContrast(2),condition.MaximumSilentLeakage, ...
        fieldOrNaN(condition.ModelRobustness,'MaximumModelLeakage'));
end
clear cleanup cleanupWarning
fprintf('test_marmoset_real_calibration: all tests passed.\n');
end


function value = fieldOrNaN(structure,name)
if isfield(structure,name)
    value = structure.(name);
else
    value = NaN;
end
end
