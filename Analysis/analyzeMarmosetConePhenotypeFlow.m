function analysis = analyzeMarmosetConePhenotypeFlow(dataSource,options)
% ANALYZEMARMOSETCONEPHENOTYPEFLOW Summarize rivalry choices and compare phenotypes.
%
% analysis = analyzeMarmosetConePhenotypeFlow(dataSource,options)
%
% dataSource: a MarmoV6 output MAT file, a loaded struct, or a cell array of
% trial structs with a PR field. Genotype is intentionally not accepted;
% compare calls with genotype only in validateMarmosetPhenotypeCalls.
%
% Each valid trial is a three-way choice: follow field A, follow field B,
% or neither. The observer model is a multinomial logit:
%   u(field) = beta * g(s),   g(s) = s/(s + c50)
%   u(none)  = theta0 + theta1*sessionPosition + theta2*eyeQuality
% where s is the field's effective cone signal under a phenotype:
%   dichromat:   |a_k| for its single ML cone k
%   trichromat:  sqrt(lum^2 + kappa*opp^2), lum = w*a_L + (1-w)*a_M,
%                opp = (a_L - a_M)/2
% and a is the realized half-amplitude Weber contrast of each cone. c50,
% w, and kappa are nuisance parameters profiled over grids and penalized
% (BIC) as free parameters. kappa = 0 describes luminance-only following.
%
% Options: BootstrapIterations (200), RandomSeed, MinimumValidTrials (40),
% MinimumClassificationConfidence (0.8), MinimumBootstrapStability (0.7),
% C50Grid, LuminanceWeightGrid, ChromaticGainGrid.

if nargin < 2 || isempty(options)
    options = struct();
end
options = setDefault(options,'BootstrapIterations',200);
options = setDefault(options,'RandomSeed',260829);
options = setDefault(options,'MinimumValidTrials',40);
options = setDefault(options,'MinimumClassificationConfidence',0.8);
options = setDefault(options,'MinimumBootstrapStability',0.7);
options = setDefault(options,'C50Grid',[0.01 0.03 0.1 0.3]);
options = setDefault(options,'LuminanceWeightGrid',[0.3 0.5 0.7]);
options = setDefault(options,'ChromaticGainGrid',[0 0.1 1]);

trials = loadTrials(dataSource);
records = extractRecords(trials);
usable = [records.TrialValid] & isfinite([records.ChoiceCode]);

analysis = struct();
analysis.SchemaVersion = 'MarmosetConePhenotypeAnalysis-2.0';
analysis.TotalTrialCount = numel(records);
analysis.ValidTrialCount = nnz(usable);
analysis.InvalidReasonCounts = countReasons(records(~usable));
analysis.PairSummary = summarizePairs(records,options);
analysis.ConditionSummary = summarizeConditions(records,options);
[analysis.RuleBasedInterpretation,analysis.RuleEvidence] = ...
    ruleBasedInterpretation(analysis.ConditionSummary,analysis.PairSummary);
analysis.PhenotypeModel = comparePhenotypes(records(usable),options);

model = analysis.PhenotypeModel;
notes = {};
if analysis.ValidTrialCount < options.MinimumValidTrials
    notes{end+1} = sprintf('only %d valid trials (minimum %d)', ...
        analysis.ValidTrialCount,options.MinimumValidTrials);
end
if ~(model.Confidence >= options.MinimumClassificationConfidence)
    notes{end+1} = sprintf('posterior %.2f below %.2f',model.Confidence, ...
        options.MinimumClassificationConfidence);
end
best = find(strcmp(model.Phenotypes,model.BestPhenotype),1);
if isempty(best) || ~(model.BootstrapBestFraction(best) >= ...
        options.MinimumBootstrapStability)
    notes{end+1} = 'bootstrap classification unstable';
end
if all(ismember({'D_556','T_543_563'},model.CompatiblePhenotypes))
    notes{end+1} = ['D_556 and T_543_563 both fit: null556 is near ' ...
        'isoluminant for a 543/563 trichromat, so weak following to it ' ...
        'does not establish a missing 556 pigment'];
end
if isempty(notes)
    analysis.Classification = model.BestPhenotype;
else
    analysis.Classification = 'unclassified';
end
analysis.ClassificationNotes = notes;
analysis.InterpretationLimitations = { ...
    'Not validated against independently genotyped animals.' ...
    'Invalid (tracking/timing) trials are excluded, never scored as unseen.' ...
    'Null conditions are receptor-silent in the pigment model, not isoluminant.' ...
    'Silence depends on assumed pigment peaks, optical density, and prereceptoral filtering.' ...
    'Rods are not silenced; check RealizedRodContrast and background luminance.'};
end


function trials = loadTrials(source)
if ischar(source) || (isstring(source) && isscalar(source))
    loaded = load(char(source));
else
    loaded = source;
end
if isstruct(loaded) && isfield(loaded,'D') && iscell(loaded.D)
    trials = loaded.D(:);
    return
end
if iscell(loaded)
    trials = loaded(:);
    return
end
if isstruct(loaded)
    names = fieldnames(loaded);
    trialNames = names(~cellfun(@isempty,regexp(names,'^D\d+$','once')));
    indices = cellfun(@(x) sscanf(x,'D%d'),trialNames);
    [~,order] = sort(indices);
    trials = cellfun(@(x) loaded.(x),trialNames(order),'UniformOutput',false);
    return
end
error('analyzeMarmosetConePhenotypeFlow:DataFormat', ...
    'Expected a MarmoV6 MAT file, loaded struct, or D cell array.');
end


function records = extractRecords(trials)
template = struct('TrialIndex',NaN,'PairID','','PairType','', ...
    'ConditionIDA','','ConditionIDB','','ConditionTypeA','', ...
    'ConditionTypeB','','AmplitudeA',nan(1,4),'AmplitudeB',nan(1,4), ...
    'TrialValid',false,'InvalidReasons',{{}},'ChoiceCode',NaN, ...
    'PreferenceIndex',NaN,'EyeQuality',NaN,'LatencyA',NaN,'LatencyB',NaN, ...
    'DistanceA',NaN,'DistanceB',NaN);
records = repmat(template,0,1);
for ii = 1:numel(trials)
    trial = trials{ii};
    if ~isstruct(trial) || ~isfield(trial,'PR') || ~isfield(trial.PR,'pairID')
        continue
    end
    pr = trial.PR;
    record = template;
    record.TrialIndex = ii;
    record.PairID = char(pr.pairID);
    record.PairType = char(pr.pairType);
    record.ConditionIDA = char(pr.conditionIDA);
    record.ConditionIDB = char(pr.conditionIDB);
    record.ConditionTypeA = char(pr.fieldConditionA.ConditionType);
    record.ConditionTypeB = char(pr.fieldConditionB.ConditionType);
    record.AmplitudeA = halfAmplitude(pr.fieldConditionA);
    record.AmplitudeB = halfAmplitude(pr.fieldConditionB);
    record.TrialValid = logical(pr.trialValid);
    record.InvalidReasons = pr.invalidReasons;
    record.ChoiceCode = pr.choiceCode;
    metrics = pr.rivalryMetrics;
    if isfield(metrics,'PreferenceIndex')
        record.PreferenceIndex = metrics.PreferenceIndex;
        record.EyeQuality = metrics.ValidEyeSampleCount/ ...
            max(1,metrics.FieldA.AnalysisSampleCount);
        record.LatencyA = metrics.FieldA.ResponseLatencySeconds;
        record.LatencyB = metrics.FieldB.ResponseLatencySeconds;
        record.DistanceA = metrics.FieldA.MedianGazeToFlowCentreDistanceDeg;
        record.DistanceB = metrics.FieldB.MedianGazeToFlowCentreDistanceDeg;
    end
    records(end+1,1) = record; %#ok<AGROW>
end
end


function amplitude = halfAmplitude(condition)
% Signed half peak-to-peak Weber contrast per candidate cone [563 556 543 423].
contrast = condition.RealizedConeContrast;
amplitude = (contrast(2,:)-contrast(1,:))/2;
end


function counts = countReasons(records)
reasons = [records.InvalidReasons];
counts = struct('Reason',{},'Count',{});
if isempty(reasons)
    return
end
uniqueReasons = unique(reasons);
for k = 1:numel(uniqueReasons)
    counts(end+1).Reason = uniqueReasons{k}; %#ok<AGROW>
    counts(end).Count = nnz(strcmp(reasons,uniqueReasons{k}));
end
end


function summaries = summarizePairs(records,options)
summaries = struct([]);
if isempty(records)
    return
end
stream = RandStream('mt19937ar','Seed',options.RandomSeed);
ids = unique({records.PairID},'stable');
for ii = 1:numel(ids)
    subset = records(strcmp({records.PairID},ids{ii}));
    usable = subset([subset.TrialValid] & isfinite([subset.ChoiceCode]));
    codes = [usable.ChoiceCode];
    item = struct();
    item.PairID = ids{ii};
    item.PairType = subset(1).PairType;
    item.ConditionIDA = subset(1).ConditionIDA;
    item.ConditionIDB = subset(1).ConditionIDB;
    item.TotalTrials = numel(subset);
    item.ValidTrials = numel(usable);
    item.ChooseA = mean(codes == 1);
    item.ChooseB = mean(codes == 2);
    item.ChooseNeither = mean(codes == 0);
    item.ChooseACI95 = bootstrapCI(double(codes == 1),options,stream);
    item.ChooseBCI95 = bootstrapCI(double(codes == 2),options,stream);
    item.ChooseNeitherCI95 = bootstrapCI(double(codes == 0),options,stream);
    preference = [usable.PreferenceIndex];
    item.MeanPreferenceIndex = mean(preference,'omitnan');
    item.PreferenceIndexCI95 = bootstrapCI(preference,options,stream);
    item.MedianLatencyA = median([usable.LatencyA],'omitnan');
    item.MedianLatencyB = median([usable.LatencyB],'omitnan');
    item.MedianDistanceA = median([usable.DistanceA],'omitnan');
    item.MedianDistanceB = median([usable.DistanceB],'omitnan');
    summaries = appendStruct(summaries,item);
end
end


function summaries = summarizeConditions(records,options)
% Convergence probability: P(gaze follows the field | field shown).
summaries = struct([]);
if isempty(records)
    return
end
stream = RandStream('mt19937ar','Seed',options.RandomSeed+2);
usable = records([records.TrialValid] & isfinite([records.ChoiceCode]));
ids = unique([{records.ConditionIDA} {records.ConditionIDB}],'stable');
for ii = 1:numel(ids)
    id = ids{ii};
    shownA = strcmp({usable.ConditionIDA},id);
    shownB = strcmp({usable.ConditionIDB},id);
    chosen = [double([usable(shownA).ChoiceCode] == 1) ...
        double([usable(shownB).ChoiceCode] == 2)];
    detection = usable(strcmp({usable.PairType},'null-catch') | ...
        strcmp({usable.PairType},'achromatic-catch'));
    detectionShown = strcmp({detection.ConditionIDA},id);
    detected = double([detection(detectionShown).ChoiceCode] == 1);
    item = struct();
    item.ConditionID = id;
    item.TrialsShown = numel(chosen);
    item.ConvergenceProbability = mean(chosen);
    item.ConvergenceProbabilityCI95 = bootstrapCI(chosen,options,stream);
    item.DetectionTrials = numel(detected);
    item.DetectionProbability = mean(detected);
    item.DetectionProbabilityCI95 = bootstrapCI(detected,options,stream);
    item.MedianCentreDistanceDeg = median([[usable(shownA).DistanceA] ...
        [usable(shownB).DistanceB]],'omitnan');
    item.MedianResponseLatencySeconds = median([[usable(shownA).LatencyA] ...
        [usable(shownB).LatencyB]],'omitnan');
    summaries = appendStruct(summaries,item);
end
catchIndex = find(strcmp({summaries.ConditionID},'catch'),1);
if ~isempty(catchIndex)
    catchCatch = usable(strcmp({usable.PairType},'catch-catch'));
    codes = [catchCatch.ChoiceCode];
    summaries(catchIndex).DetectionTrials = numel(codes);
    % Chance of following one particular invisible field.
    summaries(catchIndex).DetectionProbability = mean(codes == 1 | codes == 2)/2;
    summaries(catchIndex).DetectionProbabilityCI95 = ...
        bootstrapCI(double(codes == 1 | codes == 2)/2,options,stream);
end
end


function [interpretation,evidence] = ruleBasedInterpretation(conditions,pairs)
interpretation = 'insufficient null-condition evidence';
evidence = struct('NullPeaksNm',[543 556 563],'Detection',nan(1,3), ...
    'DetectionLowerCI',nan(1,3),'DetectionUpperCI',nan(1,3),'Chance',NaN, ...
    'Visible',false(1,3),'Invisible',false(1,3));
if isempty(conditions)
    return
end
catchIndex = find(strcmp({conditions.ConditionID},'catch'),1);
if isempty(catchIndex) || conditions(catchIndex).DetectionTrials == 0
    evidence.Chance = 0.25;
else
    evidence.Chance = conditions(catchIndex).DetectionProbability;
end
for k = 1:3
    index = find(strcmp({conditions.ConditionID}, ...
        sprintf('null%d_scale_1',evidence.NullPeaksNm(k))),1);
    if isempty(index) || conditions(index).DetectionTrials == 0
        continue
    end
    evidence.Detection(k) = conditions(index).DetectionProbability;
    evidence.DetectionLowerCI(k) = conditions(index).DetectionProbabilityCI95(1);
    evidence.DetectionUpperCI(k) = conditions(index).DetectionProbabilityCI95(2);
end
if any(~isfinite(evidence.Detection))
    return
end
margin = 0.2;
evidence.Visible = evidence.DetectionLowerCI > evidence.Chance + 0.05 & ...
    evidence.Detection >= evidence.Chance + margin;
evidence.Invisible = evidence.DetectionUpperCI < evidence.Chance + margin;
if nnz(evidence.Invisible) == 1 && nnz(evidence.Visible) == 2
    missing = evidence.NullPeaksNm(evidence.Invisible);
    interpretation = sprintf('candidate %d dichromat pattern',missing);
    if missing == 556
        interpretation = [interpretation ...
            ' (a 543/563 trichromat with luminance-driven following looks similar)'];
    end
elseif all(evidence.Visible)
    interpretation = 'candidate trichromat pattern; subtype unresolved';
else
    interpretation = 'unclassified response pattern';
end
if ~isempty(pairs)
    evidence.NullNullPreference = pairs(strcmp({pairs.PairType},'null-null'));
end
end


function model = comparePhenotypes(records,options)
labels = {'D_543','D_556','D_563','T_543_556','T_556_563','T_543_563'};
receptors = {543,556,563,[556 543],[563 556],[563 543]};
model = struct('Phenotypes',{labels},'LogEvidence',nan(1,6), ...
    'Posterior',nan(1,6),'BestPhenotype','unclassified','Confidence',NaN, ...
    'BootstrapBestFraction',nan(1,6),'CompatiblePhenotypes',{{}}, ...
    'Parameters',struct([]));
if numel(records) < 5
    return
end
[evidence,parameters] = fitAll(records,receptors,options);
posterior = exp(evidence-max(evidence));
posterior = posterior/sum(posterior);
[confidence,best] = max(posterior);

stream = RandStream('mt19937ar','Seed',options.RandomSeed+1);
bestCounts = zeros(1,numel(labels));
for iteration = 1:options.BootstrapIterations
    sample = records(randi(stream,numel(records),[1 numel(records)]));
    [~,winner] = max(fitAll(sample,receptors,options));
    bestCounts(winner) = bestCounts(winner)+1;
end
model.LogEvidence = evidence;
model.Posterior = posterior;
model.BestPhenotype = labels{best};
model.Confidence = confidence;
model.BootstrapBestFraction = bestCounts/max(1,options.BootstrapIterations);
model.CompatiblePhenotypes = labels(evidence >= max(evidence)-2);
model.Parameters = parameters;
end


function [evidence,parameters] = fitAll(records,receptorSets,options)
candidatePeaks = [563 556 543 423];
choices = [records.ChoiceCode]';
n = numel(choices);
position = zscoreSafe([records.TrialIndex]');
quality = zscoreSafe([records.EyeQuality]');
amplitudeA = vertcat(records.AmplitudeA);
amplitudeB = vertcat(records.AmplitudeB);
evidence = -inf(1,numel(receptorSets));
parameters = repmat(struct('Coefficients',[],'C50',NaN, ...
    'LuminanceWeight',NaN,'ChromaticGain',NaN,'LogLikelihood',-Inf), ...
    1,numel(receptorSets));
for h = 1:numel(receptorSets)
    cones = arrayfun(@(p) find(candidatePeaks == p),receptorSets{h});
    if numel(cones) == 1
        weights = NaN;
        gains = NaN;
        extraParameters = 1;
    else
        weights = options.LuminanceWeightGrid;
        gains = options.ChromaticGainGrid;
        extraParameters = 3;
    end
    for w = weights
        for kappa = gains
            signalA = coneSignal(amplitudeA,cones,w,kappa);
            signalB = coneSignal(amplitudeB,cones,w,kappa);
            for c50 = options.C50Grid
                gA = signalA./(signalA+c50);
                gB = signalB./(signalB+c50);
                [coefficients,logLikelihood] = fitChoiceModel(choices,gA,gB, ...
                    position,quality);
                if logLikelihood > parameters(h).LogLikelihood
                    parameters(h) = struct('Coefficients',coefficients, ...
                        'C50',c50,'LuminanceWeight',w,'ChromaticGain',kappa, ...
                        'LogLikelihood',logLikelihood);
                end
            end
        end
    end
    k = 4 + extraParameters;
    evidence(h) = parameters(h).LogLikelihood - 0.5*k*log(max(n,2));
end
end


function signal = coneSignal(amplitude,cones,w,kappa)
if numel(cones) == 1
    signal = abs(amplitude(:,cones));
else
    lum = w*amplitude(:,cones(1)) + (1-w)*amplitude(:,cones(2));
    opp = (amplitude(:,cones(1))-amplitude(:,cones(2)))/2;
    signal = sqrt(lum.^2 + kappa*opp.^2);
end
end


function [phi,logLikelihood] = fitChoiceModel(choices,gA,gB,position,quality)
% Alternatives: 1 = field A, 2 = field B, 3 = neither.
% phi = [beta theta0 theta1 theta2]; beta is constrained to be >= 0.
n = numel(choices);
X = zeros(n,3,4);
X(:,1,1) = gA;
X(:,2,1) = gB;
X(:,3,2) = 1;
X(:,3,3) = position;
X(:,3,4) = quality;
chosen = choices;
chosen(choices == 0) = 3;
[phi,logLikelihood] = newtonMNL(X,chosen,true(1,4));
if phi(1) < 0
    [phi,logLikelihood] = newtonMNL(X,chosen,[false true true true]);
end
end


function [phi,objective] = newtonMNL(X,chosen,active)
ridge = 1e-4;
p = size(X,3);
phi = zeros(p,1);
index = sub2ind([size(X,1) 3],(1:size(X,1))',chosen);
objective = penalizedLogLikelihood(X,index,phi,ridge);
for iteration = 1:50
    [probability,Xbar] = choiceProbabilities(X,phi);
    Xc = zeros(size(X,1),p);
    for j = 1:p
        column = X(:,:,j);
        Xc(:,j) = column(index);
    end
    gradient = sum(Xc-Xbar,1)' - 2*ridge*phi;
    hessian = -2*ridge*eye(p);
    for j = 1:3
        Xj = squeeze(X(:,j,:));
        hessian = hessian - Xj'*(probability(:,j).*Xj);
    end
    hessian = hessian + Xbar'*Xbar;
    step = zeros(p,1);
    step(active) = -hessian(active,active)\gradient(active);
    scale = 1;
    improved = false;
    for halving = 1:30
        candidate = phi + scale*step;
        value = penalizedLogLikelihood(X,index,candidate,ridge);
        if value >= objective
            improved = true;
            break
        end
        scale = scale/2;
    end
    if ~improved
        break
    end
    change = value-objective;
    phi = candidate;
    objective = value;
    if change < 1e-10
        break
    end
end
end


function [probability,Xbar] = choiceProbabilities(X,phi)
utility = zeros(size(X,1),3);
for j = 1:3
    utility(:,j) = squeeze(X(:,j,:))*phi;
end
utility = utility - max(utility,[],2);
probability = exp(utility);
probability = probability./sum(probability,2);
Xbar = zeros(size(X,1),size(X,3));
for j = 1:3
    Xbar = Xbar + probability(:,j).*squeeze(X(:,j,:));
end
end


function value = penalizedLogLikelihood(X,index,phi,ridge)
utility = zeros(size(X,1),3);
for j = 1:3
    utility(:,j) = squeeze(X(:,j,:))*phi;
end
maximum = max(utility,[],2);
logNormalizer = maximum + log(sum(exp(utility-maximum),2));
value = sum(utility(index)-logNormalizer) - ridge*sum(phi.^2);
end


function values = zscoreSafe(values)
values(~isfinite(values)) = mean(values(isfinite(values)));
scale = std(values);
if ~isfinite(scale) || scale == 0
    values = zeros(size(values));
else
    values = (values-mean(values))/scale;
end
end


function interval = bootstrapCI(values,options,stream)
values = values(isfinite(values));
if isempty(values)
    interval = [NaN NaN];
    return
end
estimates = zeros(options.BootstrapIterations,1);
for ii = 1:options.BootstrapIterations
    estimates(ii) = mean(values(randi(stream,numel(values),[1 numel(values)])));
end
interval = percentile(estimates,[2.5 97.5]);
end


function result = percentile(values,percentages)
values = sort(values(:));
positions = 1+(numel(values)-1)*percentages/100;
lower = floor(positions);
upper = ceil(positions);
fraction = positions-lower;
result = (values(lower).*(1-fraction) + values(upper).*fraction)';
end


function array = appendStruct(array,item)
if isempty(array)
    array = item;
else
    array(end+1) = item;
end
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
