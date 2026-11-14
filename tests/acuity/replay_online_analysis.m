function replay_online_analysis(trialTraces, trialSpatialFreq, frameRate)
% replay_online_analysis
%
% Simulates the online trial-by-trial analysis from the protocol, preserving
% the original math while improving variable names and adding detailed comments.
%
% Inputs:
%   trialTraces      - Cell array of trials; each trial is an Nx6 matrix with columns:
%                      [time, targetX, targetY, eyeX, eyeY, fixationFlag]
%   trialSpatialFreq - Numeric vector of spatial frequencies (cycles per degree) per trial
%   frameRate        - Sampling rate in Hz (frames per second)
%
% This function:
% - Computes per-trial eye-target offset plots
% - Computes and plots per-trial cross-correlation between smooth eye velocity and eye-target displacement
% - Computes a projection metric of directional alignment
% - Accumulates cross-correlation data and plots max CCG by spatial frequency

nTrials = numel(trialTraces);
maxLagSamples = frameRate * 2; % +/- 2 seconds lag window for cross-correlation

% Initialize structure to store cumulative trial results
results.ccg = nan(nTrials, 2*maxLagSamples+1);
results.meanProjection = nan(nTrials, 1);
results.numValidFrames = nan(nTrials, 1);
results.error = nan(nTrials, 1); % Placeholder for error metric
results.cpd = nan(nTrials, 1);

% Prepare figure windows for plotting
figure(1); clf; hold on; axis equal;
title('Eye-Target Offset per Trial');
xlabel('Target X - Eye X (deg)');
ylabel('Target Y - Eye Y (deg)');
xlim([-5 5]); ylim([-5 5]);

figure(2); clf;
title('Cross-Correlogram (CCG) per Trial');
xlabel('Lag (s)');
ylabel('Correlation Magnitude');

figure(3); clf; hold on;
title('Maximum CCG by Spatial Frequency');
xlabel('Spatial Frequency (cycles/deg)');
ylabel('Max Correlation Magnitude');

for trialIdx = 1:nTrials
    T = trialTraces{trialIdx};
    if isempty(T)
        continue;
    end

    fixationMask = T(:,6) == 1;
    targetX = T(fixationMask,2);
    targetY = T(fixationMask,3);
    eyePosX = T(fixationMask,4);
    eyePosY = T(fixationMask,5);

    if numel(targetX) < 2
        continue;
    end

    % Smooth eye position to reduce saccadic noise (~100 ms window)
    smoothingWindowFrames = round(0.1 * frameRate);
    smoothEyeX = smooth(eyePosX, smoothingWindowFrames);
    smoothEyeY = smooth(eyePosY, smoothingWindowFrames);

    % Calculate velocities as derivatives of smoothed positions
    eyeVelX = diff(smoothEyeX);
    eyeVelY = diff(smoothEyeY);
    targetVelX = diff(targetX);
    targetVelY = diff(targetY);

    % Number of valid velocity samples
    numValidFrames = length(eyeVelX);

    % Vector from eye position to target position (displacement vector)
    eyeToTargetX = targetX(1:end-1) - eyePosX(1:end-1);
    eyeToTargetY = targetY(1:end-1) - eyePosY(1:end-1);

    % --- Projection metric: instantaneous directional alignment ---
    % Cosine of angle between eye velocity and eye-to-target vector.
    % High values (~1) mean eye movement direction aligns well with target direction.
    projSamples = (eyeVelX .* eyeToTargetX + eyeVelY .* eyeToTargetY) ./ ...
        (sqrt(eyeVelX.^2 + eyeVelY.^2) .* sqrt(eyeToTargetX.^2 + eyeToTargetY.^2));
    meanProjection = nanmean(projSamples);

    % --- Cross-correlation (CCG) between complex eye velocity and eye-target vector ---
    % Reveals temporal relationship and lag/lead dynamics of tracking.
    crossCorr = xcorr(eyeVelX + 1i*eyeVelY, eyeToTargetX + 1i*eyeToTargetY, maxLagSamples);
    lags = (-maxLagSamples:maxLagSamples) / frameRate;

    % Store trial results for cumulative analysis
    results.ccg(trialIdx,:) = crossCorr;
    results.meanProjection(trialIdx) = meanProjection;
    results.numValidFrames(trialIdx) = numValidFrames;
    results.error(trialIdx) = 0; % Placeholder (add if available)
    if ~isempty(trialSpatialFreq) && length(trialSpatialFreq) >= trialIdx
        results.cpd(trialIdx) = trialSpatialFreq(trialIdx);
    else
        results.cpd(trialIdx) = NaN;
    end

    % --- Plot eye-target offset for current trial ---
    figure(1);
    plot(0,0,'kx','MarkerSize',12,'LineWidth',2);
    scatter(targetX - eyePosX, targetY - eyePosY, 10, 'b', 'filled');
    title(sprintf('Trial %d Eye-Target Offset', trialIdx));
    drawnow;

    % --- Plot CCG for current trial ---
    figure(2);
    plot(lags, abs(crossCorr), 'b-');
    title(sprintf('Trial %d Cross-Correlogram', trialIdx));
    drawnow;

    % --- Plot cumulative max CCG by spatial frequency ---
    figure(3);
    clf; hold on;
    uniqueCPDs = unique(results.cpd(~isnan(results.cpd)));
    maxCCGvals = zeros(size(uniqueCPDs));
    for k = 1:length(uniqueCPDs)
        idxs = results.cpd == uniqueCPDs(k);
        if any(idxs)
            weights = results.numValidFrames(idxs);
            avgCCG = sum(results.ccg(idxs,:) .* weights, 1) / sum(weights);
            maxCCGvals(k) = max(abs(avgCCG(maxLagSamples+1:end))); % positive lags only
        else
            maxCCGvals(k) = NaN;
        end
    end
    bar(uniqueCPDs, maxCCGvals);
    xlabel('Spatial Frequency (cycles/deg)');
    ylabel('Max CCG Magnitude');
    title('Max CCG by Spatial Frequency');
    drawnow;
end

fprintf('Completed replay of %d trials.\n', nTrials);
end
