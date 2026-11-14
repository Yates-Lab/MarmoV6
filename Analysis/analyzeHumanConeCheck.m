function analysis = analyzeHumanConeCheck(dataSource,options)
% ANALYZEHUMANCONECHECK Summarize a HumanConeCheckFlow session.
%
% analysis = analyzeHumanConeCheck(dataSource,options)
%
% dataSource: a MarmoV6 output MAT file, a loaded struct, or a cell array
% of trial structs with a PR field. Detection of each field is
% P(follow the field | field vs invisible catch field), compared with the
% chance of following one particular invisible field (catch vs catch).
%   nullL (M cone only) not detected, nullM detected  -> deuteranope pattern
%   nullM (L cone only) not detected, nullL detected  -> protanope pattern
%   both detected                                     -> L and M both respond
% The achromatic-achromatic pair (two identical visible fields) gives the
% reference split for the nullL-vs-nullM contest.
% Options: BootstrapIterations (1000), RandomSeed, VisibleMargin (0.2).

if nargin < 2 || isempty(options)
    options = struct();
end
options = setDefault(options,'BootstrapIterations',1000);
options = setDefault(options,'RandomSeed',20261010);
options = setDefault(options,'VisibleMargin',0.2);

trials = loadTrials(dataSource);
records = struct('PairType',{},'ConditionIDA',{},'ConditionIDB',{}, ...
    'Valid',{},'Choice',{});
for ii = 1:numel(trials)
    trial = trials{ii};
    if ~isstruct(trial) || ~isfield(trial,'PR') || ~isfield(trial.PR,'pairType')
        continue
    end
    pr = trial.PR;
    records(end+1) = struct('PairType',char(pr.pairType), ... %#ok<AGROW>
        'ConditionIDA',char(pr.conditionIDA),'ConditionIDB',char(pr.conditionIDB), ...
        'Valid',logical(pr.trialValid) && isfinite(pr.choiceCode), ...
        'Choice',pr.choiceCode);
end
valid = records([records.Valid]);
stream = RandStream('mt19937ar','Seed',options.RandomSeed);

analysis = struct();
analysis.SchemaVersion = 'HumanConeCheckAnalysis-1.0';
analysis.TotalTrialCount = numel(records);
analysis.ValidTrialCount = numel(valid);

baseline = valid(strcmp({valid.PairType},'catch-catch'));
chanceSamples = double([baseline.Choice] == 1 | [baseline.Choice] == 2)/2;
analysis.Chance = estimate(chanceSamples,options,stream);
if isempty(chanceSamples)
    analysis.Chance.Value = 0.25; % prior guess: no baseline trials recorded
end

ids = {'nullL_scale_1','nullM_scale_1','achromatic_scale_1'};
names = {'nullL','nullM','achromatic'};
for k = 1:numel(ids)
    shown = valid(ismember({valid.PairType},{'null-catch','achromatic-catch'}) & ...
        strcmp({valid.ConditionIDA},ids{k}));
    detection = estimate(double([shown.Choice] == 1),options,stream);
    detection.Visible = detection.Count > 0 && ...
        detection.CI95(1) > analysis.Chance.Value + 0.05 && ...
        detection.Value >= analysis.Chance.Value + options.VisibleMargin;
    detection.Invisible = detection.Count > 0 && ...
        detection.CI95(2) < analysis.Chance.Value + options.VisibleMargin;
    analysis.Detection.(names{k}) = detection;
end

contest = valid(strcmp({valid.PairType},'null-null'));
followedL = double(([contest.Choice] == 1 & strcmp({contest.ConditionIDA},'nullL_scale_1')) | ...
    ([contest.Choice] == 2 & strcmp({contest.ConditionIDB},'nullL_scale_1')));
followedAny = double([contest.Choice] == 1 | [contest.Choice] == 2);
analysis.ContestFollowNullL = estimate(followedL(followedAny == 1),options,stream);
analysis.ContestFollowedEither = estimate(followedAny,options,stream);

% Two identical, clearly visible fields: the split expected when both are
% seen. Compare ContestFollowNullL with VisibleBaselineFollowA.
baselinePair = valid(strcmp({valid.PairType},'achromatic-achromatic'));
baselineAny = double([baselinePair.Choice] == 1 | [baselinePair.Choice] == 2);
baselineA = double([baselinePair.Choice] == 1);
analysis.VisibleBaselineFollowA = estimate(baselineA(baselineAny == 1),options,stream);
analysis.VisibleBaselineFollowedEither = estimate(baselineAny,options,stream);

d = analysis.Detection;
if ~d.achromatic.Visible
    analysis.Interpretation = ['achromatic field not reliably followed: check ' ...
        'that you followed the swarm centres and that the session ran correctly'];
elseif d.nullL.Invisible && d.nullM.Visible
    analysis.Interpretation = 'deuteranope pattern: no response to the M-cone-only field';
elseif d.nullM.Invisible && d.nullL.Visible
    analysis.Interpretation = 'protanope pattern: no response to the L-cone-only field';
elseif d.nullL.Visible && d.nullM.Visible
    analysis.Interpretation = ['both L-only and M-only fields followed ' ...
        '(normal trichromat, or anomalous trichromat with residual L/M difference)'];
else
    analysis.Interpretation = 'unclear: more trials needed';
end
analysis.Limitations = { ...
    'A demonstration, not a clinical colour-vision test.' ...
    'With a proxy calibration the "silent" cone is only approximately silent.' ...
    'Anomalous trichromats may follow both fields, one more weakly.'};
end


function result = estimate(values,options,stream)
values = values(isfinite(values));
result = struct('Value',NaN,'CI95',[NaN NaN],'Count',numel(values));
if isempty(values)
    return
end
result.Value = mean(values);
samples = zeros(options.BootstrapIterations,1);
for ii = 1:options.BootstrapIterations
    samples(ii) = mean(values(randi(stream,numel(values),[1 numel(values)])));
end
samples = sort(samples);
result.CI95 = samples(max(1,round([0.025 0.975]*numel(samples))))';
end


function trials = loadTrials(source)
if ischar(source) || (isstring(source) && isscalar(source))
    loaded = load(char(source));
else
    loaded = source;
end
if iscell(loaded)
    trials = loaded(:);
    return
end
if isstruct(loaded) && isfield(loaded,'D') && iscell(loaded.D)
    trials = loaded.D(:);
    return
end
names = fieldnames(loaded);
trialNames = names(~cellfun(@isempty,regexp(names,'^D\d+$','once')));
[~,order] = sort(cellfun(@(x) sscanf(x,'D%d'),trialNames));
trials = cellfun(@(x) loaded.(x),trialNames(order),'UniformOutput',false);
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
