function metrics = flowRivalryMetrics(traces,fixationTraces,flipTimes,frameRate,options)
% FLOWRIVALRYMETRICS Gaze preference between two simultaneous contraction fields.
%
% traces columns (one row per displayed frame from stimulus onset, degrees):
%   1 time, 2-3 centre A xy, 4-5 centre B xy, 6-7 eye xy, 8 pupil,
%   9 stimulus displayed (1/0)
% fixationTraces columns: time, eye x, eye y, pupil (pre-stimulus fixation)
%
% A sample is valid when the eye position is finite and, if the tracker
% reports pupil size at all during the trial, the pupil is finite and
% positive. Trials without enough valid tracking are invalid; they are
% never scored as unseen. A valid trial where gaze follows neither field
% is scored as choice "none".
%
% Options (plus flowFollowingMetrics options):
%   WindowRadiusDeg          Following window around each centre (2)
%   OnsetExclusionSeconds    Excluded onset interval (0.3)
%   ChoiceMinimumFraction    Follow fraction needed for a choice (0.25)
%   ChoiceMargin             Required follow-fraction lead (0.1)
%   PreStimulusSeconds       Fixation interval used as baseline (0.1)
%   ScreenHalfSizeDeg        [half width, half height] for on-screen checks ([])

if nargin < 5 || isempty(options)
    options = struct();
end
options = setDefault(options,'WindowRadiusDeg',2);
options = setDefault(options,'OnsetExclusionSeconds',0.3);
options = setDefault(options,'ChoiceMinimumFraction',0.25);
options = setDefault(options,'ChoiceMargin',0.1);
options = setDefault(options,'PreStimulusSeconds',0.1);
options = setDefault(options,'ScreenHalfSizeDeg',[]);

traces = double(traces);
if size(traces,2) < 9
    error('flowRivalryMetrics:TraceShape', ...
        'traces must contain time, two centres, eye xy, pupil, and stimulus flag.');
end
eye = traces(:,6:7);
pupil = traces(:,8);
pupilReported = any(isfinite(pupil));
sampleValid = traces(:,9) == 1 & all(isfinite(eye),2);
if pupilReported
    sampleValid = sampleValid & isfinite(pupil) & pupil > 0;
end

preStimulusEye = [NaN NaN];
if ~isempty(fixationTraces)
    fixationTraces = double(fixationTraces);
    fixationValid = all(isfinite(fixationTraces(:,2:3)),2);
    if pupilReported && size(fixationTraces,2) >= 4
        fixationValid = fixationValid & isfinite(fixationTraces(:,4)) & ...
            fixationTraces(:,4) > 0;
    end
    recent = fixationTraces(:,1) >= fixationTraces(end,1)-options.PreStimulusSeconds;
    selected = fixationValid & recent;
    if any(selected)
        preStimulusEye = median(fixationTraces(selected,2:3),1);
    end
end

followOptions = options;
followOptions.DiscardInitialSeconds = options.OnsetExclusionSeconds;
followOptions.PreStimulusEyeDeg = preStimulusEye;
traceA = [traces(:,1) traces(:,2:3) eye double(sampleValid)];
traceB = [traces(:,1) traces(:,4:5) eye double(sampleValid)];
metricsA = marmoview.flowFollowingMetrics(traceA,flipTimes,frameRate, ...
    options.WindowRadiusDeg,followOptions);
metricsB = marmoview.flowFollowingMetrics(traceB,flipTimes,frameRate, ...
    options.WindowRadiusDeg,followOptions);
valid = metricsA.EyeValidityFlags;

distanceA = hypot(traces(:,2)-eye(:,1),traces(:,3)-eye(:,2));
distanceB = hypot(traces(:,4)-eye(:,1),traces(:,5)-eye(:,2));
followingA = valid & distanceA <= options.WindowRadiusDeg & distanceA <= distanceB;
followingB = valid & distanceB <= options.WindowRadiusDeg & distanceB < distanceA;
analysisCount = max(1,nnz(valid));

metrics = struct();
metrics.FieldA = metricsA;
metrics.FieldB = metricsB;
metrics.PupilReported = pupilReported;
metrics.SampleValidity = sampleValid;
metrics.EyeValidityFlags = valid;
metrics.ValidEyeSampleCount = nnz(valid);
metrics.PreStimulusEyeDeg = preStimulusEye;
metrics.FollowFractionA = nnz(followingA)/analysisCount;
metrics.FollowFractionB = nnz(followingB)/analysisCount;
metrics.FollowFractionEither = metrics.FollowFractionA + metrics.FollowFractionB;
total = metrics.FollowFractionA + metrics.FollowFractionB;
if total > 0
    metrics.PreferenceIndex = (metrics.FollowFractionA-metrics.FollowFractionB)/total;
else
    metrics.PreferenceIndex = NaN;
end
[metrics.VelocityGainA,metrics.VelocityGainB] = jointGains(eye,traces, ...
    valid,frameRate,options);
if isempty(options.ScreenHalfSizeDeg)
    metrics.OnScreenFraction = NaN;
else
    halfSize = options.ScreenHalfSizeDeg;
    onScreen = abs(eye(:,1)) <= halfSize(1) & abs(eye(:,2)) <= halfSize(2);
    metrics.OnScreenFraction = nnz(onScreen & valid)/analysisCount;
end

metrics.Choice = 'none';
metrics.ChoiceCode = 0;
if metrics.FollowFractionA >= options.ChoiceMinimumFraction && ...
        metrics.FollowFractionA-metrics.FollowFractionB >= options.ChoiceMargin
    metrics.Choice = 'A';
    metrics.ChoiceCode = 1;
elseif metrics.FollowFractionB >= options.ChoiceMinimumFraction && ...
        metrics.FollowFractionB-metrics.FollowFractionA >= options.ChoiceMargin
    metrics.Choice = 'B';
    metrics.ChoiceCode = 2;
end

reasons = metricsA.InvalidReasons;
if ~isempty(fixationTraces) && any(~isfinite(preStimulusEye))
    reasons{end+1} = 'no valid pre-stimulus eye position';
end
metrics.TrialValid = isempty(reasons);
metrics.InvalidReasons = reasons;
if ~metrics.TrialValid
    metrics.Choice = 'invalid';
    metrics.ChoiceCode = NaN;
end
metrics.LongFrameFraction = metricsA.LongFrameFraction;
metrics.ObservedDurationSeconds = metricsA.ObservedDurationSeconds;
end


function [gainA,gainB] = jointGains(eye,traces,valid,frameRate,options)
% Least-squares eye velocity on both centre velocities (non-saccadic samples).
gainA = NaN;
gainB = NaN;
smoothFrames = max(1,round(0.1*frameRate));
edges = diff([false; valid; false]);
starts = find(edges == 1);
stops = find(edges == -1)-1;
rows = zeros(0,2);
response = zeros(0,1);
if isfield(options,'SaccadeSpeedDegPerSecond')
    saccadeSpeed = options.SaccadeSpeedDegPerSecond;
else
    saccadeSpeed = 80;
end
for run = 1:numel(starts)
    index = starts(run):stops(run);
    if numel(index) < 3
        continue
    end
    eyeVelocity = diff(movmean(eye(index,:),smoothFrames,1),1,1)*frameRate;
    aVelocity = diff(movmean(traces(index,2:3),smoothFrames,1),1,1)*frameRate;
    bVelocity = diff(movmean(traces(index,4:5),smoothFrames,1),1,1)*frameRate;
    keep = hypot(eyeVelocity(:,1),eyeVelocity(:,2)) <= saccadeSpeed;
    rows = [rows; [aVelocity(keep,1) bVelocity(keep,1)]; ...
        [aVelocity(keep,2) bVelocity(keep,2)]]; %#ok<AGROW>
    response = [response; eyeVelocity(keep,1); eyeVelocity(keep,2)]; %#ok<AGROW>
end
if size(rows,1) >= 4 && rank(rows) == 2
    gains = rows\response;
    gainA = gains(1);
    gainB = gains(2);
end
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
