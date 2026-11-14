function test_cone_contrast_colors
% Unit test for symmetric cone-axis endpoint generation.

result = struct();
result.ConePeaks = [558 530 420];
result.RGB_to_Cones = eye(3);
result.Cones_to_RGB = eye(3);
result.BackgroundRGB = [0.5; 0.5; 0.5];
result.GammaExponent = [2 2.1 2.2];
result.InverseGamma = 1 ./ result.GammaExponent;

colors = marmoview.coneContrastColors(result,[-1 1 0],1);
assert(max(abs(colors.BackgroundLinearRGB-[0.5 0.5 0.5])) < 1e-12);
assert(max(abs(colors.NegativeLinearRGB-[1 0 0.5])) < 1e-12);
assert(max(abs(colors.PositiveLinearRGB-[0 1 0.5])) < 1e-12);
assert(max(abs(colors.NegativeConeContrast-[1 -1 0])) < 1e-12);
assert(max(abs(colors.PositiveConeContrast-[-1 1 0])) < 1e-12);
assert(abs(colors.AxisAmplitude-1) < 1e-12);
expectedBackgroundCodes = round(255* ...
    result.BackgroundRGB(:)'.^result.InverseGamma);
assert(isequal(colors.BackgroundDeviceCodes,expectedBackgroundCodes));
assert(isequal(colors.NegativeDeviceCodes,[255 0 186]));
assert(isequal(colors.PositiveDeviceCodes,[0 255 186]));

halfColors = marmoview.coneContrastColors(result,[-1 1 0],0.5);
assert(max(abs(halfColors.NegativeLinearRGB-[0.75 0.25 0.5])) < 1e-12);
assert(max(abs(halfColors.PositiveLinearRGB-[0.25 0.75 0.5])) < 1e-12);

marmoset = result;
marmoset.ConePeaks = [563 543 423];
selected = marmoview.coneContrastColors(marmoset,[1 -1 0],0.25);
assert(isequal(selected.ConePeaks,[563 543 423]));
multiple = struct('results',[result marmoset]);
assertThrows(@() marmoview.coneContrastColors(multiple,[-1 1 0],1), ...
    'coneContrastColors:ExplicitSelectionRequired');
selectedHuman = marmoview.coneContrastColors( ...
    multiple,[-1 1 0],1,[558 530 420]);
assert(isequal(selectedHuman.ConePeaks,[558 530 420]));
fprintf('test_cone_contrast_colors: all tests passed.\n');
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
