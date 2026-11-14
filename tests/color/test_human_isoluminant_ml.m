function test_human_isoluminant_ml
% Mathematical and contract tests for the human isoluminant M-L solver.

calibration = make_synthetic_human_isoluminant_calibration;
colors = marmoview.humanIsoluminantML(calibration,1);
assert(abs(colors.NegativeConeContrast(3)) < 1e-12);
assert(abs(colors.PositiveConeContrast(3)) < 1e-12);
assert(abs(colors.NegativeCIEYContrast) < 1e-12);
assert(abs(colors.PositiveCIEYContrast) < 1e-12);
assert(colors.PositiveConeContrast(2) > 0);
assert(colors.PositiveConeContrast(1) < 0);
assert(abs(colors.ConeAxis(2)-1) < 1e-12);
assert(max(abs(colors.RealizedNegativeConeContrast(3))) < 0.005);
assert(max(abs(colors.RealizedPositiveConeContrast(3))) < 0.005);
assert(max(abs([colors.RealizedNegativeCIEYContrast ...
    colors.RealizedPositiveCIEYContrast])) < 0.005);
assert(all(colors.NegativeDeviceCodes >= 0 & colors.NegativeDeviceCodes <= 65535));
assert(all(colors.PositiveDeviceCodes >= 0 & colors.PositiveDeviceCodes <= 65535));

adjusted = marmoview.humanIsoluminantML(calibration,0.5, ...
    struct('BehavioralCIEYPerMContrast',0.01));
assert(abs(adjusted.PositiveCIEYContrast/ ...
    adjusted.PositiveConeContrast(2)-0.01) < 1e-10);
assert(abs(adjusted.NegativeCIEYContrast/ ...
    adjusted.NegativeConeContrast(2)-0.01) < 1e-10);

missingY = rmfield(calibration,'PhotopicLuminanceRGB');
assertThrows(@() marmoview.humanIsoluminantML(missingY,1), ...
    'loadHumanConeCalibration:MissingMetadata');
fprintf('test_human_isoluminant_ml: all tests passed.\n');
end


function assertThrows(callable,identifier)
threw = false;
try
    callable();
catch exception
    threw = strcmp(exception.identifier,identifier);
end
assert(threw,'Expected error %s.',identifier);
end
