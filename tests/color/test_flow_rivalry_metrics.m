function test_flow_rivalry_metrics
% Synthetic two-centre gaze traces: follow A, follow B, split, neither,
% delayed following, tracker dropout, and pupil loss.

frameRate = 60;
n = 300;
t = (0:n-1)'/frameRate;
% Separated circles at different frequencies: independent velocities, and
% a gaze held at fixation is never inside either 2-degree window.
centreA = [-5+2.5*cos(2*pi*0.2*t) 2.5*sin(2*pi*0.2*t)];
centreB = [5+2.5*cos(2*pi*0.13*t+1) 2.5*sin(2*pi*0.13*t+1)];
flipTimes = t;
fixation = [(-0.2:1/frameRate:-1/frameRate)' zeros(12,2) ones(12,1)];
options = struct('WindowRadiusDeg',2,'OnsetExclusionSeconds',0.3, ...
    'MinimumValidEyeSamples',60,'MinimumDurationSeconds',1, ...
    'ScreenHalfSizeDeg',[16 9]);
trace = @(eye,pupil) [t centreA centreB eye pupil ones(n,1)];

followA = marmoview.flowRivalryMetrics(trace(centreA,ones(n,1)), ...
    fixation,flipTimes,frameRate,options);
assert(followA.TrialValid && strcmp(followA.Choice,'A') && followA.ChoiceCode == 1);
assert(followA.FollowFractionA > 0.95 && followA.FollowFractionB == 0);
assert(followA.PreferenceIndex == 1);
assert(abs(followA.VelocityGainA-1) < 0.05 && abs(followA.VelocityGainB) < 0.05);
assert(followA.FieldA.ResponseLatencySeconds <= 0.35);
assert(followA.OnScreenFraction == 1);

followB = marmoview.flowRivalryMetrics(trace(centreB,ones(n,1)), ...
    fixation,flipTimes,frameRate,options);
assert(strcmp(followB.Choice,'B') && followB.PreferenceIndex == -1);

split = [centreA(1:n/2,:); centreB(n/2+1:end,:)];
splitMetrics = marmoview.flowRivalryMetrics(trace(split,ones(n,1)), ...
    fixation,flipTimes,frameRate,options);
assert(splitMetrics.TrialValid && abs(splitMetrics.PreferenceIndex) < 0.2);
assert(strcmp(splitMetrics.Choice,'none'));

% Gaze that stays at fixation is a valid "neither", not an invalid trial.
stationary = marmoview.flowRivalryMetrics(trace(zeros(n,2),ones(n,1)), ...
    fixation,flipTimes,frameRate,options);
assert(stationary.TrialValid && strcmp(stationary.Choice,'none'));
assert(stationary.ChoiceCode == 0);
assert(isnan(stationary.FieldA.ResponseLatencySeconds));

delayFrames = 15;
delayed = [repmat(centreA(1,:),delayFrames,1); centreA(1:end-delayFrames,:)];
delayedMetrics = marmoview.flowRivalryMetrics(trace(delayed,ones(n,1)), ...
    fixation,flipTimes,frameRate,options);
assert(strcmp(delayedMetrics.Choice,'A'));
assert(abs(delayedMetrics.FieldA.BestCorrelationLagSeconds - ...
    delayFrames/frameRate) <= 2/frameRate);

dropout = centreA;
dropout(100:140,:) = NaN;
dropoutMetrics = marmoview.flowRivalryMetrics(trace(dropout,ones(n,1)), ...
    fixation,flipTimes,frameRate,options);
assert(~dropoutMetrics.TrialValid && strcmp(dropoutMetrics.Choice,'invalid'));
assert(isnan(dropoutMetrics.ChoiceCode));
assert(any(strcmp(dropoutMetrics.InvalidReasons,'eye tracker lost the animal')));

pupil = ones(n,1);
pupil(100:140) = 0; % tracker reports a lost pupil with valid-looking gaze
pupilMetrics = marmoview.flowRivalryMetrics(trace(centreA,pupil), ...
    fixation,flipTimes,frameRate,options);
assert(~pupilMetrics.TrialValid);

noPupil = marmoview.flowRivalryMetrics(trace(centreA,nan(n,1)), ...
    fixation(:,1:3),flipTimes,frameRate,options);
assert(noPupil.TrialValid && ~noPupil.PupilReported);

fprintf('test_flow_rivalry_metrics: all tests passed.\n');
end
