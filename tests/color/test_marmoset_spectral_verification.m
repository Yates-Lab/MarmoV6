function test_marmoset_spectral_verification
% Spectra predicted from the display model pass; a spectral error fails.

warning('off','marmosetPigmentNull:SilentLeakageWarning');
cleanupWarning = onCleanup(@() warning('on','marmosetPigmentNull:SilentLeakageWarning'));
fixture = make_synthetic_marmoset_calibration(8);
bank = marmoview.marmosetPhenotypeConditionBank(fixture,struct( ...
    'ExpectedMonitorIdentifier','SYNTHETIC_TEST_MONITOR','BackgroundStepSize',0.02));
patches = marmoview.marmosetVerificationPatches(bank);
assert(height(patches) == 1 + 2*(numel(bank.Conditions)-1));

measurements = struct('DeviceCodes',{},'WavelengthsNm',{},'Radiance',{});
for ii = 1:height(patches)
    codes = [patches.DeviceR(ii) patches.DeviceG(ii) patches.DeviceB(ii)];
    linear = zeros(3,1);
    for channel = 1:3
        linear(channel) = interp1(fixture.GammaDeviceInput{channel}, ...
            fixture.GammaLinearOutput{channel},codes(channel)/255);
    end
    measurements(ii).DeviceCodes = codes;
    measurements(ii).WavelengthsNm = fixture.WavelengthsNm;
    measurements(ii).Radiance = fixture.PrimarySpectra*linear;
end
report = marmoview.verifyMarmosetConditionSpectra(bank,measurements);
assert(report.Pass);
nulls = report.Conditions(strcmp({report.Conditions.ConditionType},'pigment-null'));
assert(all([nulls.MaximumSilentLeakage] < 0.005));
assert(all([nulls.SignalContrast] > 0.8*bank.MatchedContrast));

% A 3% green-primary error on one endpoint (e.g., channel interaction).
null556 = bank.Conditions(strcmp({bank.Conditions.ConditionID},'null556_scale_1'));
index = find(arrayfun(@(m) isequal(m.DeviceCodes,null556.PositiveDeviceCodes), ...
    measurements),1);
measurements(index).Radiance = measurements(index).Radiance + ...
    0.03*fixture.PrimarySpectra(:,2)*0.5;
report = marmoview.verifyMarmosetConditionSpectra(bank,measurements);
assert(~report.Pass);
failed = report.Conditions(~[report.Conditions.Pass]);
assert(isequal({failed.ConditionID},{'null556_scale_1'}));

missing = measurements(2:end);
report = marmoview.verifyMarmosetConditionSpectra(bank,missing);
assert(~report.Pass);

fprintf('test_marmoset_spectral_verification: all tests passed.\n');
end
