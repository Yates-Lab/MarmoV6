function offline_reanalysis_allTrials(TracesCell, dotsize, frameRate)
% offline_reanalysis_allTrials
%
% Offline calibration and combined plotting for multiple trials,
% calibrating eye-tracking parameters by maximizing the max cross-correlogram (CCG)
% between smoothed eye velocity and eye-target displacement vectors.
%
% Inputs:
%   TracesCell : cell array of trial matrices [time, targX, targY, eyeX, eyeY, fixgood]
%   dotsize    : vector specifying dot size (trial type) for each trial
%   frameRate  : acquisition frame rate (Hz)
%
% Example:
% offline_reanalysis_allTrials(TracesCell, dotsize, 60);

assert(iscell(TracesCell), 'First input must be a cell array of Traces');
assert(numel(TracesCell) == numel(dotsize), 'dotsize length must match number of trials');

% Pool fixation-good data across all trials for calibration
all_time = [];
all_targX = [];
all_targY = [];
all_eyeX_raw = [];
all_eyeY_raw = [];
all_fixgood = [];

valid_trials = [];

for i = 1:numel(TracesCell)
    T = TracesCell{i};
    if isempty(T) || size(T,1) < 2, continue; end
    
    fixgood = T(:,6) > 0;
    fixgood = fixgood & (abs(T(:,4))<10) & (abs(T(:,5))<10); % filter outliers
    
    if ~any(fixgood), continue; end
    
    all_time = [all_time; T(fixgood,1)];
    all_targX = [all_targX; T(fixgood,2)];
    all_targY = [all_targY; T(fixgood,3)];
    all_eyeX_raw = [all_eyeX_raw; T(fixgood,4)];
    all_eyeY_raw = [all_eyeY_raw; T(fixgood,5)];
    all_fixgood = [all_fixgood; true(sum(fixgood),1)];
    
    valid_trials = [valid_trials i];
end

if isempty(all_targX)
    error('No valid fixation data found in any trial.');
end

% --- Run calibration optimizing max CCG ---
[scaleX, scaleY, shiftX, shiftY] = combined_calibration_maxCCG(...
    all_time, all_targX, all_targY, all_eyeX_raw, all_eyeY_raw, all_fixgood, frameRate);

% Apply calibration to all trials and store calibrated eye positions
eyeX_cal_cell = cell(size(TracesCell));
eyeY_cal_cell = cell(size(TracesCell));

for i = valid_trials
    T = TracesCell{i};
    eyeX_cal_cell{i} = T(:,4) * scaleX + shiftX;
    eyeY_cal_cell{i} = T(:,5) * scaleY + shiftY;
end

% --- Plot combined eye-target offsets before and after calibration ---
figure('Name','Combined Eye-Target Offsets Before and After Calibration');
subplot(1,2,1); hold on; grid on; axis equal;
title('Before Calibration');
xlabel('Target X - Eye X (deg)'); ylabel('Target Y - Eye Y (deg)');
xlim([-5 5]); ylim([-5 5]);
plot(0,0,'kx','MarkerSize',12,'LineWidth',2);

subplot(1,2,2); hold on; grid on; axis equal;
title('After Calibration');
xlabel('Target X - Eye X (deg)'); ylabel('Target Y - Eye Y (deg)');
xlim([-5 5]); ylim([-5 5]);
plot(0,0,'kx','MarkerSize',12,'LineWidth',2);

for i = valid_trials
    T = TracesCell{i};
    fixgood = T(:,6) > 0;
    if ~any(fixgood), continue; end
    
    subplot(1,2,1);
    offX_raw = T(fixgood,2) - T(fixgood,4);
    offY_raw = T(fixgood,3) - T(fixgood,5);
    scatter(offX_raw, offY_raw, 10, 'b', 'filled');
    
    subplot(1,2,2);
    offX_cal = T(fixgood,2) - eyeX_cal_cell{i}(fixgood);
    offY_cal = T(fixgood,3) - eyeY_cal_cell{i}(fixgood);
    scatter(offX_cal, offY_cal, 10, 'g', 'filled');
end
sgtitle('Eye-Target Offset Comparison');

% --- Compute and plot combined max CCG per dot size ---
dotSizesUnique = unique(dotsize);
maxLagSecs = 1; % seconds lag window
maxLagSamples = round(maxLagSecs * frameRate);

figure('Name','Combined Max Cross-Correlograms per Dot Size');
hold on; grid on;
colors = lines(numel(dotSizesUnique));

firstValidTrial = find(cellfun(@length, TracesCell) > 6, 1);
dt = median(diff(TracesCell{firstValidTrial}(:,1)));

for iType = 1:numel(dotSizesUnique)
    type = dotSizesUnique(iType);
    
    % Accumulate weighted average CCG for all trials of this dot size
    CCG_sum = [];
    n_samples_sum = 0;
    
    for iTrial = valid_trials(dotsize(valid_trials) == type)
        T = TracesCell{iTrial};
        
        % Compute smooth velocity for calibrated eye data
        [velX, velY] = calc_smooth_velocity_with_breaks(eyeX_cal_cell{iTrial}, eyeY_cal_cell{iTrial}, T(:,1), round(0.1*frameRate));
        fixgood = T(:,6) > 0;
        validIdx = fixgood(1:end-1) & ~isnan(velX) & ~isnan(velY);
        if nnz(validIdx) < 2*maxLagSamples + 1
            continue;
        end
        
        % Compute eye-target displacement vectors
        eyePosX = eyeX_cal_cell{iTrial};
        eyePosY = eyeY_cal_cell{iTrial};
        targX = T(:,2);
        targY = T(:,3);
        
        vecTargetX = targX(2:end) - eyePosX(2:end);
        vecTargetY = targY(2:end) - eyePosY(2:end);
        
        % Cross-correlation on complex velocity & displacement
        CCG = xcorr(velX(validIdx) + 1i*velY(validIdx), ...
                     vecTargetX(validIdx) + 1i*vecTargetY(validIdx), maxLagSamples, 'coeff');
        
        if isempty(CCG_sum)
            CCG_sum = zeros(size(CCG));
        end
        
        CCG_sum = CCG_sum + CCG;
        n_samples_sum = n_samples_sum + 1;
    end
    
    %disp(n_samples_sum)
    if n_samples_sum > 0
        CCG_avg = CCG_sum / n_samples_sum;
        plot((-maxLagSamples:maxLagSamples)*dt, abs(CCG_avg), 'Color', colors(iType,:), ...
            'LineWidth', 2, 'DisplayName', sprintf('Dot size %.2f', type));
    end
end

xlabel('Lag (seconds)');
ylabel('Cross-correlation magnitude');
title('Average Cross-Correlogram by Dot Size');
legend('Location','Best');
xlim([-maxLagSecs maxLagSecs]);

% After calibration and application of scaleX, scaleY, shiftX, shiftY
% Compute and plot max CCG per dot size from recalibrated data

figure('Name', 'Max Cross-Correlogram by Dot Size (Recalibrated)');
hold on; grid on;

colors = lines(numel(dotSizesUnique)); % Use same colors as before
maxLagSamples = round(1 * frameRate); % +/-1 second lag window
dt = median(diff(all_time)); % Assuming all_time is pooled time vector

for iType = 1:numel(dotSizesUnique)
    type = dotSizesUnique(iType);

    CCG_sum = [];
    n_samples_sum = 0;

    for iTrial = valid_trials(dotsize(valid_trials) == type)
        T = TracesCell{iTrial};

        % Apply calibration
        eyeX_cal = T(:,4) * scaleX + shiftX;
        eyeY_cal = T(:,5) * scaleY + shiftY;

        % Compute smooth velocity with breaks
        [velX, velY] = calc_smooth_velocity_with_breaks(eyeX_cal, eyeY_cal, T(:,1), round(0.1 * frameRate));

        fixgood = T(:,6) > 0;
        validIdx = fixgood(1:end-1) & ~isnan(velX) & ~isnan(velY);
        if nnz(validIdx) < 2 * maxLagSamples + 1
            continue;
        end

        eyePos = [eyeX_cal(2:end), eyeY_cal(2:end)];
        targPos = [T(2:end, 2), T(2:end, 3)];
        vecTarget = targPos(validIdx, :) - eyePos(validIdx, :);

        CCG = xcorr(velX(validIdx) + 1i*velY(validIdx), vecTarget(:,1) + 1i*vecTarget(:,2), maxLagSamples, 'coeff');

        if isempty(CCG_sum)
            CCG_sum = zeros(size(CCG));
        end

        CCG_sum = CCG_sum + CCG;
        n_samples_sum = n_samples_sum + 1;
    end

    if n_samples_sum > 0
        CCG_avg = CCG_sum / n_samples_sum;
        maxCCGval = max(abs(CCG_avg));
        bar(type, maxCCGval, 'FaceColor', colors(iType, :));
    end
end

xlabel('Dot Size');
ylabel('Max Cross-Correlogram Magnitude');
title('Max CCG by Dot Size (Recalibrated Data)');
grid on;


end

% --- Helper function: smooth velocity with breaks ---
function [velX_smooth, velY_smooth] = calc_smooth_velocity_with_breaks(eyeX, eyeY, time, smooth_frames)
    diff_time = diff([0; time(:); 0]);
    seg_keep = diff_time < 0.01; % segment frames with less than 10 ms gap
    
    seg_starts = find(diff(seg_keep) == 1);
    seg_ends = find(diff(seg_keep) == -1) - 1;

    if seg_keep(1)==1
        seg_starts=[1; seg_starts];
    end
    if length(seg_ends) < length(seg_starts)
        seg_ends(end+1) = length(time);
    end

    n = length(time);
    velX_smooth = nan(n-1, 1);
    velY_smooth = nan(n-1, 1);

    for i = 1:length(seg_starts)
        s = seg_starts(i);
        e = seg_ends(i);
        if e - s < 1
            continue;
        end
        idx = s:(e-1);
        vx = diff(eyeX(s:e)) ./ diff(time(s:e));
        vy = diff(eyeY(s:e)) ./ diff(time(s:e));
        velX_smooth(idx) = movmean(vx, smooth_frames);
        velY_smooth(idx) = movmean(vy, smooth_frames);
    end
end

% --- Calibration optimizing max CCG ---
function [scaleX, scaleY, shiftX, shiftY] = combined_calibration_maxCCG(time, targX, targY, eyeX_raw, eyeY_raw, fixgood, frameRate)
    dt = median(diff(time));
    smooth_frames = max(1, round(frameRate * 0.1)); % ~100 ms smoothing
    maxLagSecs = 1;

    lb = [0.9, 0.9, -5, -5];
    ub = [1.1, 1.1, 5, 5];
    p0 = [1, 1, 0, 0];

    opts = optimoptions('fmincon', 'Display', 'iter', 'Algorithm', 'interior-point');
    lambda=0.5;
    loss_fun = @(p) maxCCG_loss_reg(p, time, targX, targY, eyeX_raw, eyeY_raw, fixgood, dt, smooth_frames, maxLagSecs, lambda);

    p_opt = fmincon(loss_fun, p0, [], [], [], [], lb, ub, [], opts);

    scaleX = p_opt(1);
    scaleY = p_opt(2);
    shiftX = p_opt(3);
    shiftY = p_opt(4);

    fprintf('Calibration params by max CCG:\nScaleX=%.4f, ScaleY=%.4f, ShiftX=%.4f deg, ShiftY=%.4f deg\n', ...
        scaleX, scaleY, shiftX, shiftY);
end

% --- Loss function maximizing max CCG ---
function loss = maxCCG_loss_reg(p, time, targX, targY, eyeX_raw, eyeY_raw, fixgood, dt, smooth_frames, maxLagSecs, lambda)
    eyeX_cal = eyeX_raw * p(1) + p(3);
    eyeY_cal = eyeY_raw * p(2) + p(4);

    [velX_smooth, velY_smooth] = calc_smooth_velocity_with_breaks(eyeX_cal, eyeY_cal, time, smooth_frames);

    valid = ~isnan(velX_smooth) & ~isnan(velY_smooth);

    eyeVel = [velX_smooth(valid), velY_smooth(valid)];
    eyePos = [eyeX_cal(2:end), eyeY_cal(2:end)];
    targPos = [targX(2:end), targY(2:end)];

    vecTarget = targPos(valid,:) - eyePos(valid,:);

    maxLagSamples = round(maxLagSecs / dt);

    % Normalize signals to zero mean, unit std for fair correlation magnitude
    eyeVel_norm = (eyeVel - mean(eyeVel))./std(eyeVel);
    vecTarget_norm = (vecTarget - mean(vecTarget))./std(vecTarget);

    CCG = xcorr(eyeVel_norm(:,1) + 1i*eyeVel_norm(:,2), vecTarget_norm(:,1) + 1i*vecTarget_norm(:,2), maxLagSamples, 'coeff');

    maxCCGval = max(abs(CCG));

    % Regularization penalizing deviation from scale=1
    reg = lambda * ((p(1)-1)^2 + (p(2)-1)^2);

    loss = -maxCCGval + reg;
end
