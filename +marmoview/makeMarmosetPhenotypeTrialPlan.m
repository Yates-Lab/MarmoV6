function plan = makeMarmosetPhenotypeTrialPlan(conditionBank,options)
% MAKEMARMOSETPHENOTYPETRIALPLAN Balanced, reproducible two-field rivalry schedule.
%
% Every trial shows two contraction fields (A and B) moving along the two
% walks of one trajectory pair. Pair types:
%   null-null         diagnostic: two contrast-matched pigment nulls
%   null-catch        detection of each null against an invisible field
%   achromatic-catch  detection of achromatic fields
%   null-achromatic   optional: null against the matched achromatic field
%   achromatic-achromatic  rivalry baseline: two identical, clearly visible
%                     fields (the same achromatic condition on both walks),
%                     so the split expected when both fields are seen
%   catch-catch       baseline: both fields invisible
%
% Every pair receives the identical sequence of (trajectory pair, walk
% assignment) combinations, cycling through all combinations before any
% repeats, so trajectory difficulty cannot differ between pairs.
%
% Options: RepeatsPerPair (12; legacy RepeatsPerCondition), TrajectoryPairCount
% (6; legacy TrajectoryCount), RandomSeed, RewardAmount, CatchTrialFraction
% (0.1, catch-catch share of all trials), IncludeDetectionPairs (true),
% IncludeAchromaticPairs (false), IncludeAchromaticBaselinePairs (true),
% MaximumRun (2).

if nargin < 2 || isempty(options)
    options = struct();
end
if isfield(options,'RepeatsPerCondition') && ~isfield(options,'RepeatsPerPair')
    options.RepeatsPerPair = options.RepeatsPerCondition;
end
if isfield(options,'TrajectoryCount') && ~isfield(options,'TrajectoryPairCount')
    options.TrajectoryPairCount = options.TrajectoryCount;
end
options = setDefault(options,'RepeatsPerPair',12);
options = setDefault(options,'TrajectoryPairCount',6);
options = setDefault(options,'RandomSeed',1);
options = setDefault(options,'RewardAmount',1);
options = setDefault(options,'CatchTrialFraction',0.1);
options = setDefault(options,'IncludeDetectionPairs',true);
options = setDefault(options,'IncludeAchromaticPairs',false);
options = setDefault(options,'IncludeAchromaticBaselinePairs',true);
options = setDefault(options,'MaximumRun',2);

repeats = round(options.RepeatsPerPair);
trajectoryCount = round(options.TrajectoryPairCount);
if repeats < 1 || trajectoryCount < 1
    error('makeMarmosetPhenotypeTrialPlan:Counts', ...
        'RepeatsPerPair and TrajectoryPairCount must be positive integers.');
end
if ~isscalar(options.CatchTrialFraction) || ...
        options.CatchTrialFraction < 0 || options.CatchTrialFraction >= 1
    error('makeMarmosetPhenotypeTrialPlan:CatchFraction', ...
        'CatchTrialFraction must be a scalar in [0,1).');
end

pairs = buildPairs(conditionBank,options);
if ~any(strcmp({pairs.PairType},'null-null'))
    error('makeMarmosetPhenotypeTrialPlan:NoDiagnosticPairs', ...
        'The condition bank must contain at least two pigment nulls per level.');
end
stream = RandStream('mt19937ar','Seed',round(options.RandomSeed));
combinations = [repelem((1:trajectoryCount)',2) repmat([1;2],trajectoryCount,1)];
schedule = zeros(0,2);
while size(schedule,1) < repeats
    schedule = [schedule; combinations(randperm(stream,size(combinations,1)),:)]; %#ok<AGROW>
end
schedule = schedule(1:repeats,:);

columns = {'PairIndex','ConditionIndexA','ConditionIndexB', ...
    'ContrastLevelIndex','TrajectoryPairIndex','WalkForA', ...
    'RepeatIndex','TrialRandomSeed','RewardAmount'};
isCatchCatch = strcmp({pairs.PairType},'catch-catch');
mainPairs = find(~isCatchCatch);
rows = zeros(numel(mainPairs)*repeats,numel(columns));
cursor = 0;
for pairIndex = mainPairs
    for repeatIndex = 1:repeats
        cursor = cursor+1;
        rows(cursor,:) = [pairIndex pairs(pairIndex).ConditionIndexA ...
            pairs(pairIndex).ConditionIndexB pairs(pairIndex).ContrastLevelIndex ...
            schedule(repeatIndex,:) repeatIndex randi(stream,2^31-1) ...
            options.RewardAmount];
    end
end
typeCodes = cellfun(@(type) find(strcmp(type,uniquePairTypes())), ...
    {pairs.PairType});
rows = constrainedShuffle(rows,typeCodes,options.MaximumRun,stream);

catchPair = find(isCatchCatch,1);
catchCount = round(options.CatchTrialFraction/(1-options.CatchTrialFraction)* ...
    size(rows,1));
if ~isempty(catchPair) && catchCount > 0
    catchRows = zeros(catchCount,numel(columns));
    for ii = 1:catchCount
        combination = combinations(mod(ii-1,size(combinations,1))+1,:);
        catchRows(ii,:) = [catchPair pairs(catchPair).ConditionIndexA ...
            pairs(catchPair).ConditionIndexB 0 combination ii ...
            randi(stream,2^31-1) options.RewardAmount];
    end
    insertAfter = round(linspace(1,size(rows,1),catchCount+2));
    insertAfter = insertAfter(2:end-1);
    for ii = catchCount:-1:1
        rows = [rows(1:insertAfter(ii),:);catchRows(ii,:); ...
            rows(insertAfter(ii)+1:end,:)];
    end
end

plan = struct();
plan.SchemaVersion = 'MarmosetPhenotypeRivalryPlan-2.0';
plan.RandomSeed = round(options.RandomSeed);
plan.Columns = columns;
plan.Rows = rows;
plan.Pairs = pairs;
plan.ConditionIDs = {conditionBank.Conditions.ConditionID};
plan.TrajectorySchedule = schedule;
plan.Options = options;
end


function pairs = buildPairs(bank,options)
conditions = bank.Conditions;
types = {conditions.ConditionType};
isNull = strcmp(types,'pigment-null');
diagnosticPeaks = [543 556 563];
if isfield(bank,'DiagnosticNullPeaksNm')
    diagnosticPeaks = bank.DiagnosticNullPeaksNm; % e.g. human [558 530]
end
isNominalNull = isNull & ismember([conditions.NullPeakNm],diagnosticPeaks);
achromatic = find(strcmp(types,'achromatic'));
catchIndex = find(strcmp(types,'catch'),1);
levelIndex = @(index) levelOf(bank,conditions(index));

pairs = struct('PairID',{},'PairType',{},'ConditionIndexA',{}, ...
    'ConditionIndexB',{},'ContrastLevelIndex',{});
for level = 1:numel(bank.ContrastLevels)
    members = find(isNominalNull & arrayfun(levelIndex,1:numel(conditions)) == level);
    for first = 1:numel(members)
        for second = first+1:numel(members)
            pairs = addPair(pairs,'null-null',conditions,members(first), ...
                members(second),level);
        end
    end
end
if logical(options.IncludeDetectionPairs) && ~isempty(catchIndex)
    for index = find(isNull)
        pairs = addPair(pairs,'null-catch',conditions,index,catchIndex, ...
            levelIndex(index));
    end
    for index = achromatic
        pairs = addPair(pairs,'achromatic-catch',conditions,index,catchIndex,0);
    end
end
if logical(options.IncludeAchromaticPairs)
    for index = find(isNominalNull)
        matches = achromatic(abs([conditions(achromatic).MatchedContrast] - ...
            conditions(index).MatchedContrast) < 1e-9);
        for match = matches
            pairs = addPair(pairs,'null-achromatic',conditions,index,match, ...
                levelIndex(index));
        end
    end
end
if logical(options.IncludeAchromaticBaselinePairs)
    for index = achromatic
        pairs = addPair(pairs,'achromatic-achromatic',conditions,index,index,0);
    end
end
if ~isempty(catchIndex)
    pairs = addPair(pairs,'catch-catch',conditions,catchIndex,catchIndex,0);
end
end


function pairs = addPair(pairs,type,conditions,first,second,level)
pairs(end+1).PairID = sprintf('%s__%s',conditions(first).ConditionID, ...
    conditions(second).ConditionID);
pairs(end).PairType = type;
pairs(end).ConditionIndexA = first;
pairs(end).ConditionIndexB = second;
pairs(end).ContrastLevelIndex = level;
end


function level = levelOf(bank,condition)
level = 0;
if strcmp(condition.ConditionType,'pigment-null')
    match = find(abs(bank.ContrastLevels-condition.AxisScale) < 1e-12,1);
    if ~isempty(match)
        level = match;
    end
end
end


function types = uniquePairTypes()
types = {'null-null','null-catch','achromatic-catch','null-achromatic', ...
    'achromatic-achromatic','catch-catch'};
end


function rows = constrainedShuffle(rows,typeCodes,maximumRun,stream)
original = rows;
for attempt = 1:1000
    remaining = original;
    candidate = zeros(size(original));
    success = true;
    for position = 1:size(candidate,1)
        permitted = true(size(remaining,1),1);
        if position > maximumRun
            recent = candidate(position-maximumRun:position-1,1);
            if all(recent == recent(1))
                permitted = permitted & remaining(:,1) ~= recent(1);
            end
            recentTypes = typeCodes(recent);
            if all(recentTypes == recentTypes(1))
                permitted = permitted & ...
                    typeCodes(remaining(:,1))' ~= recentTypes(1);
            end
        end
        permitted = find(permitted);
        if isempty(permitted)
            success = false;
            break
        end
        selected = permitted(randi(stream,numel(permitted)));
        candidate(position,:) = remaining(selected,:);
        remaining(selected,:) = [];
    end
    if success
        rows = candidate;
        return
    end
end
error('makeMarmosetPhenotypeTrialPlan:Randomization', ...
    'Unable to satisfy the consecutive-pair constraints after 1000 attempts.');
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
