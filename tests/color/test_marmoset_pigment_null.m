function test_marmoset_pigment_null
% TEST_MARMOSET_PIGMENT_NULL No-display tests for candidate-pigment axes and banks.

warning('off','marmosetPigmentNull:SilentLeakageWarning');
cleanupWarning = onCleanup(@() warning('on','marmosetPigmentNull:SilentLeakageWarning'));
fixture = make_synthetic_marmoset_calibration;
monitor = struct('ExpectedMonitorIdentifier','SYNTHETIC_TEST_MONITOR');
loaded = marmoview.loadCandidateConeCalibration(fixture,monitor);
assert(isequal(loaded.CandidateConePeaksNm,[563 556 543 423]));
assert(loaded.ModelAvailable);
assert(abs(loaded.BackgroundLuminanceCdM2-110) < 1e-9);

% Exact silence, symmetry, gamut, sign, and row selection for each null.
for peak = [543 556 563]
    condition = marmoview.marmosetPigmentNull(fixture,peak,1,monitor);
    silent = condition.SilentConeIndices;
    assert(isequal(condition.ConePeaksNm(silent),[423 peak]));
    assert(max(abs(condition.RequestedConeContrast(:,silent)),[],'all') < 1e-10);
    assert(max(abs(condition.RealizedConeContrast(:,silent)),[],'all') < 0.005);
    assert(condition.RelativeSilentLeakage <= 0.10);
    assert(all(condition.NegativeLinearRGB >= 0 & condition.NegativeLinearRGB <= 1));
    assert(all(condition.PositiveLinearRGB >= 0 & condition.PositiveLinearRGB <= 1));
    assert(max(abs((condition.NegativeLinearRGB + ...
        condition.PositiveLinearRGB)/2-condition.BackgroundLinearRGB)) < 1e-12);
    modulated = setdiff(1:3,find(condition.ConePeaksNm == peak));
    assert(abs(max(abs(condition.RequestedConeContrast(2,modulated))) - ...
        condition.MaximumSymmetricAmplitude) < 1e-12);
    longest = modulated(condition.ConePeaksNm(modulated) == ...
        max(condition.ConePeaksNm(modulated)));
    assert(condition.RequestedConeContrast(2,longest(1)) > 0);
    assert(all(isfinite(condition.RealizedRodContrast)));
    assert(condition.ModelRobustness.Available);
    assert(numel(condition.ModelRobustness.PeakOffsetLeakage) == 4);
    assert(condition.ValidationPass);
end

% Matched contrast: the largest non-silenced ML contrast equals the target.
matched = marmoview.marmosetPigmentNull(fixture,556,1, ...
    setField(monitor,'TargetContrast',0.05));
assert(abs(max(abs(matched.RequestedConeContrast(2,[1 3])))-0.05) < 1e-12);
assertThrows(@() marmoview.marmosetPigmentNull(fixture,556,1, ...
    setField(monitor,'TargetContrast',5)),'marmosetPigmentNull:TargetContrast');

% Off-nominal nulls for sweeps are opt-in; unknown peaks are rejected.
assertThrows(@() marmoview.marmosetPigmentNull(fixture,545,1), ...
    'marmosetPigmentNull:NullPeak');
assertThrows(@() marmoview.marmosetPigmentNull(fixture,530,1), ...
    'marmosetPigmentNull:NullPeak');
offNominal = marmoview.marmosetPigmentNull(fixture,545,0.5, ...
    setField(monitor,'AllowOffNominalPeak',true));
assert(max(abs(offNominal.RequestedNullPigmentContrast)) < 1e-10);
assert(offNominal.NominalNullPeakNm == 543);

% Leakage is judged relative to the delivered signal.
eightBit = make_synthetic_marmoset_calibration(8);
relativeOptions = setField(monitor,'SilentLeakageTolerance',1);
assertThrows(@() marmoview.marmosetPigmentNull(eightBit,556,0.01, ...
    relativeOptions),'marmosetPigmentNull:RelativeLeakage');

% Background override recomputes background excitation.
override = marmoview.marmosetPigmentNull(fixture,563,1, ...
    setField(monitor,'BackgroundLinearRGB',[0.5 0.3 0.4]));
assert(isequal(override.BackgroundLinearRGB,[0.5 0.3 0.4]));
assert(max(abs(override.RequestedConeContrast(:,override.SilentConeIndices)),[],'all') < 1e-10);

% Calibration contract.
wrongOrder = fixture;
wrongOrder.CandidateConePeaksNm = [543 556 563 423];
assertThrows(@() marmoview.loadCandidateConeCalibration(wrongOrder), ...
    'loadCandidateConeCalibration:ConeOrder');
dummy = fixture;
dummy.IsDummyCalibration = true;
assertThrows(@() marmoview.loadCandidateConeCalibration(dummy), ...
    'loadCandidateConeCalibration:DummyCalibration');
assertThrows(@() marmoview.loadCandidateConeCalibration(fixture, ...
    struct('ExpectedMonitorIdentifier','WRONG_MONITOR')), ...
    'loadCandidateConeCalibration:MonitorMismatch');
assertThrows(@() marmoview.loadCandidateConeCalibration(fixture, ...
    struct('MaximumCalibrationAgeDays',365)), ...
    'loadCandidateConeCalibration:CalibrationAge');
undated = fixture;
undated.CalibrationDate = 'unknown';
assertThrows(@() marmoview.loadCandidateConeCalibration(undated, ...
    struct('MaximumCalibrationAgeDays',365)), ...
    'loadCandidateConeCalibration:CalibrationDate');
tampered = fixture;
tampered.CandidateRGBToCones(2,1) = tampered.CandidateRGBToCones(2,1)*1.001;
tampered.CandidateBackgroundExcitations = ...
    tampered.CandidateRGBToCones*tampered.BackgroundLinearRGB(:);
assertThrows(@() marmoview.loadCandidateConeCalibration(tampered), ...
    'loadCandidateConeCalibration:ModelMismatch');
modelless = rmfield(fixture,'NomogramModel');
assertThrows(@() marmoview.loadCandidateConeCalibration(modelless, ...
    struct('RequireModel',true)),'loadCandidateConeCalibration:ModelMissing');
humanOnly = struct('ConePeaks',[558 530 420], ...
    'RGB_to_Cones',eye(3),'BackgroundRGB',[0.5 0.5 0.5]);
assertThrows(@() marmoview.marmosetPhenotypeConditionBank(humanOnly), ...
    'loadCandidateConeCalibration:MissingMetadata');

% Condition bank: optimized background, matched contrast, controls.
bankOptions = struct('ExpectedMonitorIdentifier','SYNTHETIC_TEST_MONITOR', ...
    'MinimumBackgroundLuminanceCdM2',60,'BackgroundStepSize',0.02, ...
    'AchromaticContrastScales',[0.5 1]);
bank = marmoview.marmosetPhenotypeConditionBank(fixture,bankOptions);
assert(bank.BackgroundLuminanceCdM2 >= 60-1e-9);
assert(bank.BackgroundSelection.MatchedContrastLimit >= ...
    bank.BackgroundSelection.ReferenceMatchedContrastLimit);
ids = {bank.Conditions.ConditionID};
assert(all(ismember({'null543_scale_1','null556_scale_1','null563_scale_1', ...
    'achromatic_scale_0.5','achromatic_scale_1','catch'},ids)));
for condition = bank.Conditions(strcmp({bank.Conditions.ConditionType},'pigment-null'))
    modulated = setdiff(1:3,find(condition.ConePeaksNm == condition.NullPeakNm));
    assert(abs(max(abs(condition.RequestedConeContrast(2,modulated))) - ...
        bank.MatchedContrast) < 1e-12);
    assert(isequal(condition.BackgroundLinearRGB,bank.BackgroundLinearRGB));
end
achromatic = bank.Conditions(strcmp(ids,'achromatic_scale_1'));
assert(max(abs(achromatic.RequestedConeContrast(2,:)-bank.MatchedContrast)) < 1e-12);
catchCondition = bank.Conditions(strcmp(ids,'catch'));
assert(isequal(catchCondition.NegativeDeviceCodes,catchCondition.BackgroundDeviceCodes));
assert(isequal(catchCondition.PositiveDeviceCodes,catchCondition.BackgroundDeviceCodes));
exportedBank = marmoview.marmosetPhenotypeConditionBank(fixture, ...
    setField(bankOptions,'BackgroundMode','exported'));
assert(isequal(exportedBank.BackgroundLinearRGB,[0.5 0.5 0.5]));
assert(bank.MatchedContrast >= exportedBank.MatchedContrast);
assertThrows(@() marmoview.marmosetPhenotypeConditionBank(fixture, ...
    setField(bankOptions,'MinimumBackgroundLuminanceCdM2',1000)), ...
    'optimizeMarmosetBackground:Infeasible');
sweep = marmoview.marmosetPhenotypeConditionBank(fixture, ...
    setField(setField(bankOptions,'NullSweepOffsetsNm',[-2 0 2]), ...
    'MatchedContrastFraction',0.5));
assert(nnz(strcmp({sweep.Conditions.ConditionType},'pigment-null')) == 9);

fprintf('test_marmoset_pigment_null: all tests passed.\n');
end


function value = setField(value,name,fieldValue)
value.(name) = fieldValue;
end


function assertThrows(callable,identifier)
threw = false;
message = '';
try
    callable();
catch exception
    threw = strcmp(exception.identifier,identifier);
    message = exception.identifier;
end
assert(threw,'Expected error %s, got "%s".',identifier,message);
end
