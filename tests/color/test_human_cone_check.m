function test_human_cone_check
% Human L/M cone-check bank, trial plan, and blinded simulated observers.

taskRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(taskRoot,'Analysis'));
calibration = syntheticHumanCalibration();
bank = marmoview.humanConeCheckConditionBank(calibration);
ids = {bank.Conditions.ConditionID};
assert(isequal(ids,{'nullL_scale_1','nullM_scale_1','achromatic_scale_1','catch'}));

% nullL: L and S silent, M at the matched contrast; nullM: the reverse.
nullL = bank.Conditions(1);
nullM = bank.Conditions(2);
assert(max(abs(nullL.RequestedConeContrast(:,[1 3])),[],'all') < 1e-10);
assert(max(abs(nullM.RequestedConeContrast(:,[2 3])),[],'all') < 1e-10);
assert(abs(nullL.RequestedConeContrast(2,2)-bank.MatchedContrast) < 1e-12);
assert(abs(nullM.RequestedConeContrast(2,1)-bank.MatchedContrast) < 1e-12);
assert(nullL.MaximumSilentLeakage < 0.005 && nullM.MaximumSilentLeakage < 0.005);
for condition = bank.Conditions
    assert(max(abs((condition.NegativeLinearRGB+condition.PositiveLinearRGB)/2 - ...
        condition.BackgroundLinearRGB)) < 1e-12);
end
achromatic = bank.Conditions(3);
assert(max(abs(achromatic.RequestedConeContrast(2,:)-bank.MatchedContrast)) < 1e-12);
assertThrows(@() marmoview.humanConeCheckConditionBank(calibration, ...
    struct('ExpectedMonitorIdentifier','OTHER')),'humanConeCheckConditionBank:MonitorMismatch');

% The shared trial plan recognises the human diagnostic pair.
plan = marmoview.makeMarmosetPhenotypeTrialPlan(bank,struct( ...
    'RepeatsPerPair',20,'TrajectoryPairCount',5,'RandomSeed',2,'CatchTrialFraction',0.1));
types = {plan.Pairs.PairType};
assert(nnz(strcmp(types,'null-null')) == 1);
assert(nnz(strcmp(types,'null-catch')) == 2);
assert(nnz(strcmp(types,'achromatic-catch')) == 1);
assert(nnz(strcmp(types,'achromatic-achromatic')) == 1);

% Simulated observers: a field is followed when one of their cones sees it.
observers = {[1 1],'both L-only and M-only'; [1 0],'deuteranope'; [0 1],'protanope'};
for k = 1:size(observers,1)
    D = simulate(bank,plan,observers{k,1},10+k);
    analysis = analyzeHumanConeCheck(D,struct('BootstrapIterations',300));
    assert(contains(analysis.Interpretation,observers{k,2}), ...
        'Observer %d interpreted as: %s',k,analysis.Interpretation);
    % Identical visible fields: followed on most trials, split about evenly.
    assert(analysis.VisibleBaselineFollowedEither.Value > 0.8);
    assert(analysis.VisibleBaselineFollowA.CI95(1) < 0.5 && ...
        analysis.VisibleBaselineFollowA.CI95(2) > 0.5);
end

% The Dell proxy builds (with an explicit dummy opt-in only).
proxy = fullfile(taskRoot,'SupportData','ConeCalibration','HumanIsoluminantML', ...
    'ConeMath2026_proxy_results.mat');
if exist(proxy,'file')
    assertThrows(@() marmoview.humanConeCheckConditionBank(proxy), ...
        'loadHumanConeCalibration:DummyCalibration');
    proxyBank = marmoview.humanConeCheckConditionBank(proxy,struct('AllowDummy',true));
    fprintf(['test_human_cone_check: Dell proxy matched contrast %.3f; ' ...
        'leakage nullL %.4f, nullM %.4f\n'],proxyBank.MatchedContrast, ...
        proxyBank.Conditions(1).MaximumSilentLeakage, ...
        proxyBank.Conditions(2).MaximumSilentLeakage);
end
fprintf('test_human_cone_check: all tests passed.\n');
end


function D = simulate(bank,plan,hasCone,seed)
% hasCone = [L M]; following probability rises with the visible cone signal.
stream = RandStream('mt19937ar','Seed',seed);
D = cell(size(plan.Rows,1),1);
for ii = 1:size(plan.Rows,1)
    pair = plan.Pairs(plan.Rows(ii,1));
    fields = bank.Conditions([pair.ConditionIndexA pair.ConditionIndexB]);
    signal = zeros(1,2);
    for k = 1:2
        amplitude = abs(fields(k).RealizedConeContrast(2,1:2));
        signal(k) = max(amplitude.*hasCone);
    end
    utility = [60*signal 1];
    probability = exp(utility)/sum(exp(utility));
    choice = find(rand(stream) <= cumsum(probability),1);
    codes = [1 2 0];
    pr = struct('pairType',pair.PairType,'conditionIDA',fields(1).ConditionID, ...
        'conditionIDB',fields(2).ConditionID,'trialValid',true,'choiceCode',codes(choice));
    D{ii} = struct('PR',pr);
end
end


function calibration = syntheticHumanCalibration()
wavelengths = (380:780)';
primary = @(peak,width) exp(-0.5*((wavelengths-peak)/width).^2);
spectra = [primary(610,14) primary(545,22) primary(455,12)];
spectra = spectra./sum(spectra,1).*[0.9 1.0 0.6];
model = struct('SpecificDensityPerMicron',0.015,'OuterSegmentLengthMicrons',20, ...
    'PreRetinalTransmittance',[]);
device = linspace(0,1,4097)';
calibration = struct();
calibration.ConePeaks = [558 530 420];
calibration.RGB_to_Cones = marmoview.pigmentFundamentals(model,wavelengths, ...
    [558 530 420])*spectra;
calibration.BackgroundRGB = [0.5 0.5 0.5];
calibration.PhotopicLuminanceRGB = [0.07 0.23 0.02];
calibration.PhotopicLuminanceConvention = 'synthetic test';
calibration.GammaDeviceInput = {device device device};
calibration.GammaLinearOutput = {device.^2.2 device.^2.2 device.^2.2};
calibration.BitDepth = 16;
calibration.GammaApplication = 'software-encoded';
calibration.MonitorIdentifier = 'SYNTHETIC_HUMAN_MONITOR';
calibration.CalibrationChecksumSHA256 = 'SYNTHETIC_HUMAN_TEST_FIXTURE';
calibration.CalibrationDate = '2000-01-01';
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
