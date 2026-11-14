function test_flow_following_metrics
% Synthetic perfect, random, delayed, stationary, gap, and missing-eye tests.

frameRate = 60;
n = 300;
t = (0:n-1)'/frameRate;
target = [2*sin(2*pi*0.25*t) 1.5*cos(2*pi*0.25*t)];
flipTimes = t;
options = struct('MinimumValidEyeSamples',60, ...
    'MaximumLongFrameFraction',0.05,'MinimumDurationSeconds',1);

perfect = [t target target ones(n,1)];
perfectMetrics = marmoview.flowFollowingMetrics( ...
    perfect,flipTimes,frameRate,2,options);
assert(perfectMetrics.TrialValid);
assert(perfectMetrics.MedianGazeToFlowCentreDistanceDeg < 1e-10);
assert(perfectMetrics.BestCorrelation > 0.95);
assert(abs(perfectMetrics.PursuitGain-1) < 0.05);

stream = RandStream('mt19937ar','Seed',7);
randomEye = 3*randn(stream,n,2);
randomMetrics = marmoview.flowFollowingMetrics( ...
    [t target randomEye ones(n,1)],flipTimes,frameRate,2,options);
assert(randomMetrics.MedianGazeToFlowCentreDistanceDeg > ...
    perfectMetrics.MedianGazeToFlowCentreDistanceDeg);
assert(randomMetrics.BestCorrelation < perfectMetrics.BestCorrelation);

% Positive lag means the eye trails the centre.
delayFrames = 12;
delayedEye = [repmat(target(1,:),delayFrames,1);target(1:end-delayFrames,:)];
delayedMetrics = marmoview.flowFollowingMetrics( ...
    [t target delayedEye ones(n,1)],flipTimes,frameRate,2,options);
assert(delayedMetrics.TrialValid);
assert(abs(delayedMetrics.BestCorrelationLagSeconds-delayFrames/frameRate) <= 2/frameRate);

% A stationary eye that starts on the centre has no response latency and
% does not approach the centre relative to its pre-stimulus position.
stationaryEye = repmat(target(1,:),n,1);
stationaryOptions = options;
stationaryOptions.PreStimulusEyeDeg = target(1,:);
stationary = marmoview.flowFollowingMetrics( ...
    [t target stationaryEye ones(n,1)],flipTimes,frameRate,2,stationaryOptions);
assert(isnan(stationary.ResponseLatencySeconds));
assert(abs(stationary.PrePostDistanceChangeDeg) < 1e-12);
movingOptions = stationaryOptions;
following = marmoview.flowFollowingMetrics( ...
    [t target delayedEye ones(n,1)],flipTimes,frameRate,2,movingOptions);
assert(following.PrePostDistanceChangeDeg < -0.5);
assert(following.ResponseLatencySeconds >= 0.25 && ...
    following.ResponseLatencySeconds < 1.5);

% A dropout longer than the limit invalidates the trial.
gap = perfect;
gap(120:150,6) = 0;
gap(120:150,4:5) = NaN;
gapMetrics = marmoview.flowFollowingMetrics(gap,flipTimes,frameRate,2,options);
assert(~gapMetrics.TrialValid);
assert(any(strcmp(gapMetrics.InvalidReasons,'eye tracker lost the animal')));
assert(abs(gapMetrics.PursuitGain-1) < 0.05); % no velocity across the gap

missing = perfect;
missing(:,4:5) = NaN;
missing(:,6) = 0;
missingMetrics = marmoview.flowFollowingMetrics( ...
    missing,flipTimes,frameRate,2,options);
assert(~missingMetrics.TrialValid);
assert(any(strcmp(missingMetrics.InvalidReasons, ...
    'insufficient valid eye samples')));

fprintf('test_flow_following_metrics: all tests passed.\n');
end
