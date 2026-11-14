function test_marmoset_phenotype_flow_infrastructure
% No-display tests for walk pairs, rivalry trial plans, rendering guards, persistence.

warning('off','marmosetPigmentNull:SilentLeakageWarning');
cleanupWarning = onCleanup(@() warning('on','marmosetPigmentNull:SilentLeakageWarning'));
fixture = make_synthetic_marmoset_calibration;
bank = marmoview.marmosetPhenotypeConditionBank(fixture,struct( ...
    'ExpectedMonitorIdentifier','SYNTHETIC_TEST_MONITOR', ...
    'BackgroundStepSize',0.02,'ContrastLevels',[0.5 1]));

% Walk pairs: reproducible, bounded, equidistant start, separated, independent.
trajectoryOptions = struct('FrameRate',60,'StimulusDuration',3, ...
    'TrajectoryPairCount',4,'RandomSeed',42,'SpeedDegPerSecond',6, ...
    'MaximumEccentricityDeg',7,'FilterTimeConstantSeconds',0.3, ...
    'StartOffsetDeg',2.5,'MinimumCentreSeparationDeg',4, ...
    'MaximumVelocityCorrelation',0.2);
walksA = marmoview.makeMarmosetFlowTrajectoryBank(trajectoryOptions);
walksB = marmoview.makeMarmosetFlowTrajectoryBank(trajectoryOptions);
assert(isequal(walksA.XDeg,walksB.XDeg) && isequal(walksA.YDeg,walksB.YDeg));
assert(isequal(size(walksA.XDeg),[4 2 180]));
assert(max(hypot(walksA.XDeg,walksA.YDeg),[],'all') <= 7+1e-12);
for pair = 1:4
    startA = [walksA.XDeg(pair,1,1) walksA.YDeg(pair,1,1)];
    startB = [walksA.XDeg(pair,2,1) walksA.YDeg(pair,2,1)];
    assert(abs(norm(startA)-2.5) < 1e-12 && max(abs(startA+startB)) < 1e-12);
    separation = hypot(squeeze(walksA.XDeg(pair,1,:)-walksA.XDeg(pair,2,:)), ...
        squeeze(walksA.YDeg(pair,1,:)-walksA.YDeg(pair,2,:)));
    assert(min(separation) >= 4);
    assert(abs(walksA.VelocityCorrelation(pair)) <= 0.2);
end
speeds = zeros(4,2);
for pair = 1:4
    for walk = 1:2
        steps = diff([squeeze(walksA.XDeg(pair,walk,:)) ...
            squeeze(walksA.YDeg(pair,walk,:))])*60;
        speeds(pair,walk) = median(hypot(steps(:,1),steps(:,2)));
    end
end
assert(all(abs(speeds(:)-6) < 1.0));

% Trial plan: reproducible, balanced, identical trajectory schedule per pair.
planOptions = struct('RepeatsPerPair',12,'TrajectoryPairCount',6, ...
    'RandomSeed',99,'RewardAmount',2,'CatchTrialFraction',0.1);
planA = marmoview.makeMarmosetPhenotypeTrialPlan(bank,planOptions);
planB = marmoview.makeMarmosetPhenotypeTrialPlan(bank,planOptions);
assert(isequal(planA.Rows,planB.Rows));
columns = planA.Columns;
column = @(name) planA.Rows(:,strcmp(columns,name));
pairIndex = column('PairIndex');
types = {planA.Pairs.PairType};
assert(nnz(strcmp(types,'null-null')) == 6); % 3 pairs at each of 2 levels
assert(nnz(strcmp(types,'null-catch')) == 6);
assert(nnz(strcmp(types,'achromatic-catch')) == 1);
baselinePair = planA.Pairs(strcmp(types,'achromatic-achromatic'));
assert(numel(baselinePair) == 1);
assert(baselinePair.ConditionIndexA == baselinePair.ConditionIndexB);
assert(strcmp(bank.Conditions(baselinePair.ConditionIndexA).ConditionType,'achromatic'));
assert(nnz(strcmp(types,'catch-catch')) == 1);
reference = [];
for k = find(~strcmp(types,'catch-catch'))
    rows = pairIndex == k;
    assert(nnz(rows) == 12);
    trajectories = column('TrajectoryPairIndex');
    walks = column('WalkForA');
    combination = sortrows([trajectories(rows) walks(rows)]);
    if isempty(reference)
        reference = combination;
    end
    assert(isequal(combination,reference));
    assert(size(unique(combination,'rows'),1) == 12);
    counts = accumarray(combination(:,1),1,[6 1]);
    assert(all(counts == 2));
    assert(nnz(combination(:,2) == 1) == 6);
    pair = planA.Pairs(k);
    assert(all(column('ConditionIndexA') == pair.ConditionIndexA | ~rows));
end
typeSequence = cellfun(@(t) find(strcmp(t,unique(types,'stable'))),types(pairIndex));
assert(maxRun(pairIndex) <= 2);
assert(maxRun(typeSequence) <= 2);
catchRows = find(strcmp(types(pairIndex),'catch-catch'));
assert(numel(catchRows) >= 3 && max(diff(catchRows)) <= ...
    ceil(size(planA.Rows,1)/numel(catchRows))+1);
seeds = column('TrialRandomSeed');
assert(numel(unique(seeds)) == numel(seeds));

% Rendering guards and polarity balance (no window needed).
stimulus = stimuli.opticflow(0);
stimulus.position = [50 50];
stimulus.screenRect = [0 0 100 100];
stimulus.Xbot = 0;
stimulus.Xtop = 100;
stimulus.Ytop = 0;
stimulus.Ybot = 100;
stimulus.maxRadius = inf;
stimulus.centerDecay = false;
stimulus.balancedDots = true;
stimulus.polarityColours = [40 210;70 190;100 170];
stimulus.neutralColour = [125;125;125];
stimulus.nDots = 100;
stimulus.exactColour = true;
stimulus.dotType = 1;
assertThrows(@() stimulus.beforeTrial(),'opticflow:ExactColourDotType');
stimulus.dotType = 0;
stimulus.dotContrast = 0.5;
assertThrows(@() stimulus.beforeTrial(),'opticflow:ExactColourContrast');
stimulus.dotContrast = 1;
stimulus.beforeTrial();
assert(nnz(stimulus.dotPolarity < 0) == 50 && nnz(stimulus.dotPolarity > 0) == 50);
assert(isequal(unique(stimulus.dotColours','rows'),sortrows([40 70 100;210 190 170])));
stimulus.nDots = 101;
stimulus.beforeTrial();
assert(nnz(stimulus.dotPolarity < 0) == 50 && nnz(stimulus.dotPolarity > 0) == 50);
assert(nnz(stimulus.dotPolarity == 0) == 1);
polarityBefore = stimulus.dotPolarity;
for frame = 1:40
    stimulus.afterFrame();
end
assert(isequal(stimulus.dotPolarity,polarityBefore));

% Everything needed to reconstruct a session survives save/load.
saved = struct('ConditionBank',bank,'TrajectoryBank',walksA,'TrialPlan',planA);
filename = [tempname '.mat'];
cleanup = onCleanup(@() deleteIfPresent(filename));
save(filename,'saved');
reloaded = load(filename,'saved');
assert(isequaln(saved,reloaded.saved));
clear cleanup

fprintf('test_marmoset_phenotype_flow_infrastructure: all tests passed.\n');
end


function count = maxRun(sequence)
count = 1;
current = 1;
for ii = 2:numel(sequence)
    if sequence(ii) == sequence(ii-1)
        current = current+1;
        count = max(count,current);
    else
        current = 1;
    end
end
end


function deleteIfPresent(filename)
if exist(filename,'file')
    delete(filename);
end
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
