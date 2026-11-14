function results = benchmark_opticflow_placement(nFrames)
%BENCHMARK_OPTICFLOW_PLACEMENT Compare legacy and clean dot-update CPU cost.
% This excludes Screen('DrawDots') and must be followed by an on-rig flip
% timing comparison. It exercises the exact lifetime/replacement paths.

if nargin < 1
    nFrames = 600;
end

pixPerDeg = 38.862991;
legacy = configureStimulus(false,0,pixPerDeg);
clean = configureStimulus(true,0.75*pixPerDeg,pixPerDeg);

results.legacy = timeStimulus(legacy,nFrames);
results.clean = timeStimulus(clean,nFrames);
results.cleanToLegacyMeanRatio = ...
    results.clean.meanFrameMs/results.legacy.meanFrameMs;
results.frameBudgetMsAt60Hz = 1000/60;
results.cleanP99FractionOf60HzBudget = ...
    results.clean.p99FrameMs/results.frameBudgetMsAt60Hz;
results.cleanP99WithinQuarterFrameBudget = ...
    results.cleanP99FractionOf60HzBudget < 0.25;

fprintf('Legacy update: mean %.3f ms, p99 %.3f ms, max %.3f ms\n', ...
    results.legacy.meanFrameMs,results.legacy.p99FrameMs, ...
    results.legacy.maxFrameMs);
fprintf('Clean update:  mean %.3f ms, p99 %.3f ms, max %.3f ms\n', ...
    results.clean.meanFrameMs,results.clean.p99FrameMs, ...
    results.clean.maxFrameMs);
fprintf('Clean/legacy mean ratio: %.2fx; 60-Hz budget: %.3f ms\n', ...
    results.cleanToLegacyMeanRatio,results.frameBudgetMsAt60Hz);
fprintf('Clean p99 uses %.1f%% of the 60-Hz frame budget\n', ...
    100*results.cleanP99FractionOf60HzBudget);
if ~results.cleanP99WithinQuarterFrameBudget
    warning('Clean placement p99 exceeds 25%% of the 60-Hz frame budget.');
end
end

function stimulus = configureStimulus(balanced,minSeparationPix,pixPerDeg)
stimulus = stimuli.opticflow([]);
stimulus.setRandomSeed(20260829);
stimulus.position = [1280 720];
stimulus.size = pixPerDeg/(2*11);
stimulus.f = 0.1;
stimulus.depth = 10;
stimulus.dotdepth = 1;
stimulus.vxyz = [0 0 -0.1];
stimulus.nDots = 2500;
stimulus.balancedDots = balanced;
stimulus.dotContrast = 1;
stimulus.minSeparationPix = minSeparationPix;
stimulus.placementAttempts = 50;
stimulus.maxRadius = inf;
stimulus.Xbot = 0;
stimulus.Xtop = 2560;
stimulus.Ytop = 0;
stimulus.Ybot = 1440;
stimulus.lifetime = 30;
stimulus.centerDecay = true;
stimulus.beforeTrial();
end

function timing = timeStimulus(stimulus,nFrames)
frameMs = zeros(nFrames,1);
for frame = 1:nFrames
    frameTimer = tic;
    stimulus.afterFrame();
    frameMs(frame) = 1000*toc(frameTimer);
end
sortedMs = sort(frameMs);
p99Index = max(1,ceil(0.99*nFrames));
timing.meanFrameMs = mean(frameMs);
timing.p99FrameMs = sortedMs(p99Index);
timing.maxFrameMs = max(frameMs);
timing.placementTimeMs = 1000*stimulus.placementTimeSeconds;
timing.placementCalls = stimulus.placementCalls;
timing.placementCandidates = stimulus.placementCandidateCount;
timing.placementDistanceChecks = stimulus.placementDistanceChecks;
timing.placementFallbacks = stimulus.placementFallbackCount;
end
