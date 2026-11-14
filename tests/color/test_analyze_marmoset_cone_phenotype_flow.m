function test_analyze_marmoset_cone_phenotype_flow
% Simulated blinded sessions: each phenotype's choices are generated from the
% observer model, then analyzed without the phenotype being supplied.

taskRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
analysisPath = fullfile(taskRoot,'Analysis');
addpath(analysisPath);
cleanup = onCleanup(@() rmpath(analysisPath));
warning('off','marmosetPigmentNull:SilentLeakageWarning');
cleanupWarning = onCleanup(@() warning('on','marmosetPigmentNull:SilentLeakageWarning'));

fixture = make_synthetic_marmoset_calibration;
bank = marmoview.marmosetPhenotypeConditionBank(fixture,struct( ...
    'ExpectedMonitorIdentifier','SYNTHETIC_TEST_MONITOR','BackgroundStepSize',0.02));
plan = marmoview.makeMarmosetPhenotypeTrialPlan(bank,struct( ...
    'RepeatsPerPair',24,'TrajectoryPairCount',6,'RandomSeed',5, ...
    'CatchTrialFraction',0.1));
options = struct('BootstrapIterations',30,'RandomSeed',11, ...
    'MinimumValidTrials',40,'MinimumClassificationConfidence',0.8, ...
    'MinimumBootstrapStability',0.6);

% Dichromats: the silent null loses every contest and is never detected.
for truth = {'D_543','D_556','D_563'}
    D = simulateSession(bank,plan,truth{1},struct('w',0.5,'kappa',1),21);
    result = analyzeMarmosetConePhenotypeFlow(D,options);
    assert(strcmp(result.PhenotypeModel.BestPhenotype,truth{1}), ...
        'Simulated %s recovered as %s.',truth{1},result.PhenotypeModel.BestPhenotype);
    missing = sscanf(truth{1},'D_%d');
    assert(contains(result.RuleBasedInterpretation,sprintf('%d dichromat',missing)));
    assert(result.ValidTrialCount == nnz(cellfun(@(d) d.PR.trialValid,D)));
end

% A trichromat with chromatic following is not called a dichromat.
D = simulateSession(bank,plan,'T_543_563',struct('w',0.5,'kappa',1),22);
result = analyzeMarmosetConePhenotypeFlow(D,options);
assert(startsWith(result.PhenotypeModel.BestPhenotype,'T_'));
assert(contains(result.RuleBasedInterpretation,'trichromat'));

% Invalid trials are excluded rather than scored as unseen.
D = simulateSession(bank,plan,'D_556',struct('w',0.5,'kappa',1),23);
for ii = 1:10
    D{ii}.PR.trialValid = false;
    D{ii}.PR.choiceCode = NaN;
    D{ii}.PR.invalidReasons = {'eye tracker lost the animal'};
end
result = analyzeMarmosetConePhenotypeFlow(D,options);
assert(result.ValidTrialCount == numel(D)-10);
assert(result.InvalidReasonCounts(1).Count == 10);

% Too little data is unclassified.
result = analyzeMarmosetConePhenotypeFlow(D(1:20),options);
assert(strcmp(result.Classification,'unclassified'));

clear cleanup cleanupWarning
fprintf('test_analyze_marmoset_cone_phenotype_flow: all tests passed.\n');
end


function D = simulateSession(bank,plan,phenotype,nuisance,seed)
receptorMap = struct('D_543',543,'D_556',556,'D_563',563, ...
    'T_543_556',[556 543],'T_556_563',[563 556],'T_543_563',[563 543]);
peaks = [563 556 543 423];
cones = arrayfun(@(p) find(peaks == p),receptorMap.(phenotype));
stream = RandStream('mt19937ar','Seed',seed);
columns = plan.Columns;
D = cell(size(plan.Rows,1),1);
for ii = 1:size(plan.Rows,1)
    row = plan.Rows(ii,:);
    pair = plan.Pairs(row(strcmp(columns,'PairIndex')));
    conditionA = bank.Conditions(pair.ConditionIndexA);
    conditionB = bank.Conditions(pair.ConditionIndexB);
    gA = transducer(signal(conditionA,cones,nuisance));
    gB = transducer(signal(conditionB,cones,nuisance));
    utility = [8*gA 8*gB 1];
    probability = exp(utility)/sum(exp(utility));
    choice = find(rand(stream) <= cumsum(probability),1);
    codes = [1 2 0];
    pr = struct();
    pr.pairID = pair.PairID;
    pr.pairType = pair.PairType;
    pr.conditionIDA = conditionA.ConditionID;
    pr.conditionIDB = conditionB.ConditionID;
    pr.fieldConditionA = conditionA;
    pr.fieldConditionB = conditionB;
    pr.trialValid = true;
    pr.invalidReasons = {};
    pr.choiceCode = codes(choice);
    field = struct('AnalysisSampleCount',282,'ResponseLatencySeconds',0.4, ...
        'MedianGazeToFlowCentreDistanceDeg',1);
    pr.rivalryMetrics = struct('PreferenceIndex',[1 -1 0]*[choice==1; ...
        choice==2; choice==3],'ValidEyeSampleCount',270, ...
        'FieldA',field,'FieldB',field);
    D{ii} = struct('PR',pr);
end
end


function s = signal(condition,cones,nuisance)
contrast = condition.RealizedConeContrast;
amplitude = (contrast(2,:)-contrast(1,:))/2;
if numel(cones) == 1
    s = abs(amplitude(cones));
else
    lum = nuisance.w*amplitude(cones(1)) + (1-nuisance.w)*amplitude(cones(2));
    opp = (amplitude(cones(1))-amplitude(cones(2)))/2;
    s = sqrt(lum^2 + nuisance.kappa*opp^2);
end
end


function g = transducer(s)
g = s/(s+0.03);
end
