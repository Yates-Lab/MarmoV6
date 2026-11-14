function calibration = make_synthetic_human_isoluminant_calibration
% MAKE_SYNTHETIC_HUMAN_ISOLUMINANT_CALIBRATION Test fixture only.

calibration = struct();
calibration.SchemaVersion = 'SYNTHETIC-TEST-1.0';
calibration.ConePeaks = [558 530 420];
calibration.RGB_to_Cones = [1.20 0.35 0.08; 0.40 1.10 0.12; 0.05 0.16 1.25];
calibration.BackgroundRGB = [0.5 0.5 0.5];
backgroundExcitation = calibration.RGB_to_Cones*calibration.BackgroundRGB(:);
luminanceRow = calibration.RGB_to_Cones(1,:)/backgroundExcitation(1) + ...
    calibration.RGB_to_Cones(2,:)/backgroundExcitation(2);
calibration.PhotopicLuminanceRGB = luminanceRow/sum(luminanceRow);
calibration.PhotopicLuminanceConvention = ...
    'CIE 1931 2-degree y-bar integrated against energy-calibrated primaries';
device = linspace(0,1,65536)';
calibration.GammaDeviceInput = {device device device};
calibration.GammaLinearOutput = {device.^2.2 device.^2.2 device.^2.2};
calibration.BitDepth = 16;
calibration.GammaApplication = 'software-encoded';
calibration.MonitorIdentifier = 'SYNTHETIC_TEST_MONITOR';
calibration.CalibrationDate = '2000-01-01';
end
