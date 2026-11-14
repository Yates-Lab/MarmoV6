function metrics = flowFollowingMetrics(traces,flipTimes,frameRate,windowRadius,options)
% FLOWFOLLOWINGMETRICS Pursuit/convergence metrics and validity for one flow centre.
%
% traces columns: time, centre x, centre y, eye x, eye y, sample valid (1/0),
% in degrees with one row per displayed frame from stimulus onset.
%
% Options:
%   DiscardInitialSeconds     Onset interval excluded from all metrics (0.25)
%   PreStimulusEyeDeg         Eye position before stimulus onset ([] = first valid)
%   MaximumLagSeconds         Cross-correlation lag range (1)
%   MinimumValidEyeSamples    (frameRate)
%   MaximumEyeGapSeconds      Longest tolerated tracker dropout (0.3)
%   MaximumLongFrameFraction  (0.05)
%   MinimumDurationSeconds    (1)
%   CalibrationStable         (true)
%   SaccadeSpeedDegPerSecond  Eye speed excluded from pursuit gain (80)
%   LatencyImprovementDeg     Gain over a stationary eye defining a response (1)
%   LatencySustainSeconds     Duration the gain must persist (0.1)

if nargin < 5 || isempty(options)
    options = struct();
end
options = setDefault(options,'DiscardInitialSeconds',0.25);
options = setDefault(options,'PreStimulusEyeDeg',[]);
options = setDefault(options,'MaximumLagSeconds',1);
options = setDefault(options,'MinimumValidEyeSamples',round(frameRate));
options = setDefault(options,'MaximumEyeGapSeconds',0.3);
options = setDefault(options,'MaximumLongFrameFraction',0.05);
options = setDefault(options,'MinimumDurationSeconds',1);
options = setDefault(options,'CalibrationStable',true);
options = setDefault(options,'SaccadeSpeedDegPerSecond',80);
options = setDefault(options,'LatencyImprovementDeg',1);
options = setDefault(options,'LatencySustainSeconds',0.1);

traces = double(traces);
if size(traces,2) < 6
    error('flowFollowingMetrics:TraceShape', ...
        'traces must contain time, target XY, eye XY, and validity columns.');
end
nFrames = size(traces,1);
sampleValid = traces(:,6) == 1 & all(isfinite(traces(:,2:5)),2);
discard = min(nFrames,round(options.DiscardInitialSeconds*frameRate));
inAnalysis = true(nFrames,1);
inAnalysis(1:discard) = false;
valid = sampleValid & inAnalysis;

target = traces(:,2:3);
eye = traces(:,4:5);
distance = hypot(target(:,1)-eye(:,1),target(:,2)-eye(:,2));
stationaryEye = reshape(double(options.PreStimulusEyeDeg),1,[]);
if numel(stationaryEye) ~= 2 || any(~isfinite(stationaryEye))
    firstValid = find(sampleValid,1);
    if isempty(firstValid)
        stationaryEye = [NaN NaN];
    else
        stationaryEye = eye(firstValid,:);
    end
end
stationaryDistance = hypot(target(:,1)-stationaryEye(1), ...
    target(:,2)-stationaryEye(2));

metrics = struct();
metrics.EyeValidityFlags = valid;
metrics.ValidEyeSampleCount = nnz(valid);
metrics.AnalysisSampleCount = nnz(inAnalysis);
metrics.LongestEyeGapSeconds = longestRun(~sampleValid(inAnalysis))/frameRate;
metrics.MedianGazeToFlowCentreDistanceDeg = median(distance(valid),'omitnan');
metrics.FractionInsideCentreWindow = mean(distance(valid) <= windowRadius);
metrics.PreStimulusEyeDeg = stationaryEye;
metrics.PreStimulusDistanceDeg = median(stationaryDistance(valid),'omitnan');
metrics.PostStimulusDistanceDeg = metrics.MedianGazeToFlowCentreDistanceDeg;
metrics.PrePostDistanceChangeDeg = ...
    metrics.PostStimulusDistanceDeg - metrics.PreStimulusDistanceDeg;
metrics.ResponseLatencySeconds = responseLatency(stationaryDistance-distance, ...
    valid,options.LatencyImprovementDeg, ...
    max(1,round(options.LatencySustainSeconds*frameRate)),frameRate);

% Velocities only within contiguous runs of valid samples.
smoothFrames = max(1,round(0.1*frameRate));
[eyeVelocity,targetVelocity,velocityValid] = runVelocities(eye,target, ...
    valid,smoothFrames,frameRate);
towardCentre = target-eye;
towardCentre = towardCentre./max(eps,hypot(towardCentre(:,1),towardCentre(:,2)));
projection = sum(eyeVelocity.*towardCentre,2);
metrics.MeanEyeVelocityProjectionTowardCentre = ...
    mean(projection(velocityValid),'omitnan');
nonSaccadic = velocityValid & ...
    hypot(eyeVelocity(:,1),eyeVelocity(:,2)) <= options.SaccadeSpeedDegPerSecond;
metrics.PursuitGain = sum(eyeVelocity(nonSaccadic,:).*targetVelocity(nonSaccadic,:),'all') / ...
    max(eps,sum(targetVelocity(nonSaccadic,:).^2,'all'));
if ~any(nonSaccadic)
    metrics.PursuitGain = NaN;
end
maximumLag = round(options.MaximumLagSeconds*frameRate);
% Positive lags: the eye trails the centre.
metrics.EyeCentreCrossCorrelation = laggedCorrelation(targetVelocity, ...
    eyeVelocity,velocityValid,maximumLag);
metrics.CrossCorrelationLagsSeconds = (-maximumLag:maximumLag)/frameRate;
metrics.BestCorrelation = NaN;
metrics.BestCorrelationLagSeconds = NaN;
if any(isfinite(metrics.EyeCentreCrossCorrelation))
    [metrics.BestCorrelation,index] = max(metrics.EyeCentreCrossCorrelation);
    metrics.BestCorrelationLagSeconds = metrics.CrossCorrelationLagsSeconds(index);
end

flipTimes = double(flipTimes(:));
intervals = diff(flipTimes);
intervals = intervals(isfinite(intervals) & intervals > 0);
expectedInterval = 1/frameRate;
metrics.LongFrameCount = nnz(intervals > 1.5*expectedInterval);
metrics.LongFrameFraction = metrics.LongFrameCount/max(1,numel(intervals));
metrics.MeanFrameIntervalMs = 1000*mean(intervals);
metrics.MaxFrameIntervalMs = 1000*max([intervals; NaN]);
metrics.ObservedDurationSeconds = nFrames/frameRate;

reasons = {};
if metrics.ValidEyeSampleCount < options.MinimumValidEyeSamples
    reasons{end+1} = 'insufficient valid eye samples';
end
if metrics.LongestEyeGapSeconds > options.MaximumEyeGapSeconds
    reasons{end+1} = 'eye tracker lost the animal';
end
if metrics.LongFrameFraction > options.MaximumLongFrameFraction
    reasons{end+1} = 'excessive frame drops';
end
if metrics.ObservedDurationSeconds < options.MinimumDurationSeconds
    reasons{end+1} = 'trial too short';
end
if ~options.CalibrationStable
    reasons{end+1} = 'calibration changed';
end
metrics.TrialValid = isempty(reasons);
metrics.InvalidReasons = reasons;
end


function [eyeVelocity,targetVelocity,velocityValid] = runVelocities(eye,target, ...
        valid,smoothFrames,frameRate)
n = size(eye,1);
eyeVelocity = nan(n,2);
targetVelocity = nan(n,2);
velocityValid = false(n,1);
edges = diff([false; valid; false]);
starts = find(edges == 1);
stops = find(edges == -1)-1;
for run = 1:numel(starts)
    index = starts(run):stops(run);
    if numel(index) < 3
        continue
    end
    smoothEye = movmean(eye(index,:),smoothFrames,1);
    smoothTarget = movmean(target(index,:),smoothFrames,1);
    eyeVelocity(index(2:end),:) = diff(smoothEye,1,1)*frameRate;
    targetVelocity(index(2:end),:) = diff(smoothTarget,1,1)*frameRate;
    velocityValid(index(2:end)) = true;
end
end


function correlations = laggedCorrelation(first,second,valid,maximumLag)
lags = -maximumLag:maximumLag;
correlations = nan(size(lags));
n = size(first,1);
for ii = 1:numel(lags)
    lag = lags(ii);
    if lag >= 0
        a = 1:n-lag;
        b = 1+lag:n;
    else
        a = 1-lag:n;
        b = 1:n+lag;
    end
    keep = valid(a) & valid(b);
    if nnz(keep) < 3
        continue
    end
    x = first(a(keep),:);
    y = second(b(keep),:);
    denominator = sqrt(sum(x.^2,'all')*sum(y.^2,'all'));
    if denominator > 0
        correlations(ii) = sum(x.*y,'all')/denominator;
    end
end
end


function latency = responseLatency(improvement,valid,threshold,sustain,frameRate)
% First frame after which the eye stays closer to the centre than a
% stationary pre-stimulus eye would, by at least threshold degrees.
latency = NaN;
responding = valid & improvement >= threshold;
run = 0;
for frame = 1:numel(responding)
    if responding(frame)
        run = run+1;
        if run >= sustain
            latency = (frame-sustain)/frameRate;
            return
        end
    elseif valid(frame)
        run = 0;
    end
end
end


function count = longestRun(mask)
count = 0;
current = 0;
for ii = 1:numel(mask)
    if mask(ii)
        current = current+1;
        count = max(count,current);
    else
        current = 0;
    end
end
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
