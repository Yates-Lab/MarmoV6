
%% CPU-only tests for hartleyplaid_cpu
clear; clc;

% --- basic params
S.pixPerDeg   = 60;
S.screenRect  = [0 0 641 481];       % odd dims -> exact center at 0 deg
contrast      = 0.4;
ns            = 25;
seed          = 123;

hp = hartleyplaid_cpu('screenRect', S.screenRect, ...
                    'pixPerDeg',  S.pixPerDeg, ...
                    'FmaxX', 8, 'FmaxY', 8, ...
                    'K', 6, 'contrast', contrast, ...
                    'ns', ns, 'seed', seed);

fprintf('Strides: sx=%d, sy=%d; grid nx,ny from ns=%d\n', hp.strideKx, hp.strideKy, ns);

%% 0) FFT peak test (K=1, exact frequency match up to ±k)
hp.K = 1;
hp = hp.sampleComponents();
% force a single known component i (pick a mid-ish one to avoid edges)
i = ceil(numel(hp.bank)/4);
hp.current.idx   = i;
hp.current.fx    = hp.bank(i).fx;
hp.current.fy    = hp.bank(i).fy;
hp.current.phase = pi/4;                     % canonical +k phase
hp.current.amp   = contrast;

[Iu8, Ilin] = hp.renderFrame(); %#ok<ASGLU>

[fx_hat, fy_hat, dmin] = local_fft_peak(Ilin, S.pixPerDeg, hp.current.fx, hp.current.fy);
fprintf('FFT peak (%.3f, %.3f) c/deg vs bank ±(%.3f, %.3f) — Δ=%.3g\n', ...
    fx_hat, fy_hat, hp.current.fx, hp.current.fy, dmin);

%% 1) Phase-center test: pixel at exact center should be bg + amp*sin(phi)
% Center pixel index:
w = RectWidth(hp.screenRect); h = RectHeight(hp.screenRect);
cx = (w+1)/2; cy = (h+1)/2;
phis = [+pi/4, -pi/4, +3*pi/4, -3*pi/4];

fprintf('\nPhase-center test (center should follow bg + A*sin(phi)):\n');
for ph = phis
    hp.current.phase = ph;
    hp.current.amp   = contrast;
    [~, Ilin] = hp.renderFrame();
    centerLSB = Ilin(cy,cx)*255;
    expected  = (hp.bgGrey + contrast * sin(ph)) * 255;
    fprintf('phi=%6.2f rad : center = %6.2f LSB  (expect ~ %6.2f)\n', ph, centerLSB, expected);
end

%% 2) Cancel test: +k with pi/4 and -k with +pi/4 should cancel (Hartley pair)
hp.K = 2;
% choose a +k from half-plane and its partner:
iPlus = ceil(numel(hp.bank)/4);
iMinus = hp.bank(iPlus).opp;

hp.current.idx   = [iPlus, iMinus];
hp.current.fx    = [hp.bank(iPlus).fx, hp.bank(iMinus).fx];
hp.current.fy    = [hp.bank(iPlus).fy, hp.bank(iMinus).fy];
hp.current.phase = [pi/4, -pi/4];       % cas pair
hp.current.amp   = [contrast, contrast];   % equal amp

[~, Ilin] = hp.renderFrame();
dev = (Ilin - hp.bgGrey);
fprintf('\nCancel test a: mean |dev| = %.3f LSB (want ~0)\n', mean(abs(dev(:)))*255);

%% 2b) Cancel test: +k with -pi/4 and +k with -3pi/4 should cancel (pi out of phase)
hp.K = 2;
% choose a +k from half-plane and its partner:
iPlus = ceil(numel(hp.bank)/4);
iMinus = hp.bank(iPlus).opp;

hp.current.idx   = [iPlus, iPlus];
hp.current.fx    = [hp.bank(iPlus).fx, hp.bank(iPlus).fx];
hp.current.fy    = [hp.bank(iPlus).fy, hp.bank(iPlus).fy];
hp.current.phase = [pi/4, pi/4 + pi];       % cas pair
hp.current.amp   = [contrast, contrast];   % equal amp

[~, Ilin] = hp.renderFrame();
dev = (Ilin - hp.bgGrey);
fprintf('\nCancel test b: mean |dev| = %.3f LSB (want ~0)\n', mean(abs(dev(:)))*255);

%% 3) RMS vs K (should be ~ contrast/sqrt(2) * 255, independent of K)
fprintf('\nRMS vs K (contrast=%.3f): expected LSB = %.2f\n', contrast, contrast/sqrt(2)*255);
Ks = [1 2 4 6 8 12];
for K = Ks
    hp.K = K;
    rms_vals = zeros(1,8);
    for t = 1:numel(rms_vals)
        hp = hp.sampleComponents();
        [~, Ilin] = hp.renderFrame();
        dev = (Ilin - hp.bgGrey);
        rms_vals(t) = std(dev(:))*255;
    end
    fprintf('K=%2d: RMS = %.2f LSB  (mean of %d frames)\n', K, mean(rms_vals), numel(rms_vals));
end

%% 4) Mean luminance near bg
hp.K = 6;
hp = hp.sampleComponents();
[~, Ilin] = hp.renderFrame();
m = mean(Ilin(:))*255; s = std(Ilin(:))*255;
fprintf('\nMean luminance: %.2f ± %.2f LSB (bg=%.0f)\n', m, s, hp.bgGrey*255);

%% 5) Opp mapping sanity
ok = true;
n = numel(hp.bank);
for ii = 1:n
    jj = hp.bank(ii).opp;
    ok = ok && (abs(hp.bank(ii).fx + hp.bank(jj).fx) < 1e-12) ...
            && (abs(hp.bank(ii).fy + hp.bank(jj).fy) < 1e-12) ...
            && (hp.bank(jj).opp == ii);
end
fprintf('\nopp mapping %s.\n', tern(ok,'OK','FAILED'));

%% 6) Shift-vs-phase test
% For a single component, a spatial shift (dx,dy) is equivalent to phase += 2π(fx dx + fy dy)
hp.K = 1;
% pick a nonzero k:
i = find(arrayfun(@(b) hypot(b.fx,b.fy)>0, hp.bank), 1, 'first');
hp.current.idx   = i;
hp.current.fx    = hp.bank(i).fx;
hp.current.fy    = hp.bank(i).fy;
hp.current.phase = pi/4;
hp.current.amp   = contrast;

dx_deg = 0.25; dy_deg = -0.15;
[~, Ishift] = local_render_with_shift(hp, dx_deg, dy_deg);

dphi = 2*pi*(hp.current.fx*dx_deg + hp.current.fy*dy_deg);
hp.current.phase = hp.current.phase + dphi;
[~, Iphase] = hp.renderFrame();

mae = mean(abs((Ishift(:)-Iphase(:))*255));
fprintf('\nShift-vs-phase MAE: %.3f LSB (want ~0; small residuals = numeric roundoff)\n', mae);

%% 7) Multi-component FFT spot check (use the largest peak and nearest ±k)
hp.K = 6;
hp = hp.sampleComponents();
[~, Ilin] = hp.renderFrame();
[fx_hat, fy_hat, dmin] = local_fft_peak(Ilin, S.pixPerDeg, hp.current.fx, hp.current.fy);
fprintf('\nMulti-K FFT strongest peak (%.3f, %.3f) c/deg — Δ to nearest ±k = %.3g\n', fx_hat, fy_hat, dmin);


%% --- Convert CPU Hartley log to Moosavi–Tring–Ringach 2025 format ---
% Simulating a few "presentations" by sampling components
nFrames = 100;                 % number of test frames to log
hp.K = 6;                      % ensure same K as in experiment
logs = cell(nFrames,1);

for t = 1:nFrames
    hp = hp.sampleComponents();
    fx = hp.current.fx(:);
    fy = hp.current.fy(:);
    amp = hp.current.amp(:);
    signVal = sign(amp);                   % Moosavi's s = ±1
    kx = round(fx * RectWidth(hp.screenRect) / hp.pixPerDeg);   % integer lattice index
    ky = round(fy * RectHeight(hp.screenRect) / hp.pixPerDeg);  % integer lattice index

    % Build one row per component (matches Moosavi .db layout)
    logs{t} = table(repmat(t,numel(kx),1), signVal(:), kx(:), ky(:), amp(:), ...
                    'VariableNames',{'frame','sign','kx','ky','amp'});
end

log = vertcat(logs{:});

% Optional: add dummy eye position, area, speed fields for compatibility
log.xpos   = zeros(height(log),1);
log.ypos   = zeros(height(log),1);
log.area   = repmat("V1",height(log),1);
log.speed  = zeros(height(log),1);
log.signal = cell(height(log),1);  % placeholder for neural data

% Save in .db format
save('hartley_tester_export.db','log','-v7.3');

fprintf('Exported %d frames to hartley_tester_export.db (Moosavi format)\n', nFrames);


%% --- Quick visual cross-check with Moosavi-style reconstruction ---
% Recreate one of the logged gratings directly from the exported log table.

% Load the exported file (or use the current 'log' in workspace)
if ~exist('log','var')
    load('hartley_tester_export.db','log');
end

% Pick one entry to visualize
i = 10;   % can pick any row
kx   = log.kx(i);
ky   = log.ky(i);
s    = log.sign(i);

% --- Define spatial grid in visual degrees ---
w = RectWidth(hp.screenRect);
h = RectHeight(hp.screenRect);
Wdeg = w / hp.pixPerDeg;
Hdeg = h / hp.pixPerDeg;

% Sampling grid (match your stimulus pixel grid)
[xPix, yPix] = meshgrid((1:w)-(w+1)/2, (1:h)-(h+1)/2);
Xdeg =  xPix / hp.pixPerDeg;
Ydeg = -yPix / hp.pixPerDeg;   % flip to match your convention (Y up)

% --- Recreate Hartley pattern ---
phase = 2*pi*(kx * Xdeg / Wdeg + ky * Ydeg / Hdeg);
stim  = s * (cos(phase) + sin(phase));

% Normalize and convert to [0,1] display intensities
stim = stim / max(abs(stim(:)));
Ilin = 0.5 + 0.5 * stim;

% --- Display ---
figure('Color','w');
imagesc(Xdeg(1,:), Ydeg(:,1), Ilin);
axis image; colormap(gray(256));
xlabel('Horizontal position (deg)');
ylabel('Vertical position (deg)');
title(sprintf('Recreated Hartley grating: kx=%d, ky=%d, sign=%+d', kx, ky, s));
colorbar;

% This should match the recreation of the Moosavi et al gratings



%%
%% ----------------------------------------------------------
%  PIXEL-PERFECT VALIDATION: CPU vs GPU vs getImage vs Log Reconstruction
%  ----------------------------------------------------------

% % Following requires Marmoview
% % Setup a small test window:
% Screen('Preference','SkipSyncTests',1);
% S0=S;
% S = MarmoViewRigSettings;  % fill out rest of needed params for PTB
% S.screenRect=S0.screenRect;
% S.pixPerDeg=S0.pixPerDeg;
% A = marmoview.openScreen(S);
% 
% fprintf('\n--- Pixel-Perfect Hartley Validation ---\n');
% 
% % Ensure we have the hartleyplaid_static object
% hp = stimuli.hartleyplaid_static(A.window, ...
%     'screenRect', A.screenRect, ...
%     'pixPerDeg', 60, ...
%     'maxSF', 8, ...
%     'K', 6, ...
%     'contrast', 0.4);
% 
% % Pick one known frame (make it deterministic)
% hp.rng = RandStream('mt19937ar','Seed',123);
% hp.sampleComponents();

%% (1) CPU analytic reconstruction
% Build all atoms as unit-contrast, mean-zero Hartley functions
w = RectWidth(hp.screenRect);
h = RectHeight(hp.screenRect);
[Xdeg, Ydeg] = meshgrid((1:w)-(w+1)/2, (1:h)-(h+1)/2);
Xdeg =  Xdeg / hp.pixPerDeg;
Ydeg = -Ydeg / hp.pixPerDeg;

acc = zeros(size(Xdeg));
for j = 1:hp.K
    acc = acc + hp.current.amp(j) * ...
        sin(2*pi*(hp.current.fx(j).*Xdeg + hp.current.fy(j).*Ydeg) + pi/4);
end
cpu_img = hp.bgGrey + acc;
cpu_img = min(max(cpu_img,0),1);

%% (2) GPU render (on-screen)
% Screen('FillRect', hp.winPtr, hp.bgGrey);
% hp.beforeFrame();
% vbl = Screen('Flip', A.window);
% gpu_img = mean(Screen('GetImage', hp.winPtr, hp.screenRect, [], 1),3);  % float mode
% gpu_img = min(max(gpu_img,0),1);
gpu_img=zeros(size(cpu_img));
%% (3) getImage() (CPU from marmoview stimulus hartleyplaid_static)
% Iu8 = hp.getImage(hp.screenRect);
% getimg_img = double(Iu8)/255;
getimg_img=ones(size(cpu_img));
%% (4) Recreate from exported log (simulate Moosavi format)
% --- Recreate from exported log (multi-component Hartley pattern) ---
fx = hp.current.fx(:);
fy = hp.current.fy(:);
amp = hp.current.amp(:);
signVal = sign(amp);
K = numel(fx);

Wdeg = RectWidth(hp.screenRect)/hp.pixPerDeg;
Hdeg = RectHeight(hp.screenRect)/hp.pixPerDeg;
kx = round(fx * Wdeg);
ky = round(fy * Hdeg);

acc = zeros(size(Xdeg));
for j = 1:K
    phase = 2*pi*(kx(j) * Xdeg / Wdeg + ky(j) * Ydeg / Hdeg);
    acc = acc + signVal(j) * sin(phase + pi/4);   % same as buildTextures()
end
log_img = hp.bgGrey + (hp.contrast/sqrt(K)) * acc;
log_img = min(max(log_img,0),1);


% % Normalize and convert to [0,1]
% acc = acc / max(abs(acc(:)));
% log_img = 0.5 + 0.5 * acc;

%



%% (5) Compare pixelwise differences
to255 = @(x) uint8(round(x*255));
cpu_u8    = to255(cpu_img);
gpu_u8    = to255(gpu_img);
getimg_u8 = to255(getimg_img);
log_u8    = to255(log_img);

% fprintf('CPU↔GPU MAE = %.3f LSB\n', mean(abs(double(cpu_u8(:)) - double(gpu_u8(:)))));% requires marmoview
% fprintf('CPU↔getImage MAE = %.3f LSB\n', mean(abs(double(cpu_u8(:)) - double(getimg_u8(:)))));% requires marmoview
fprintf('CPU↔LogRecon MAE = %.3f LSB\n', mean(abs(double(cpu_u8(:)) - double(log_u8(:)))));

%% (6) Visual overlay
figure('Color','w');
subplot(2,3,1); imshow(cpu_u8); title('CPU Analytic'); 
% subplot(2,3,2); imshow(gpu_u8); title('GPU (DrawTextures)'); % requires marmoview
% subplot(2,3,3); imshow(getimg_u8); title('getImage() CPU'); % requires marmoview
subplot(2,3,4); imshow(log_u8); title('Recreated from Log');
subplot(2,3,[5 6]); imshow(abs(double(cpu_u8)-double(gpu_u8)),[]); 
title('CPU–GPU |diff| (LSB)');
colormap(gca,'parula'); colorbar;


% --- Pixel-Perfect Hartley Validation ---
% CPU↔GPU MAE = 0.250 LSB
% CPU↔getImage MAE = 0.000 LSB
% CPU↔LogRecon MAE = 0.000 LSB
%%

figure(2)
subplot(221)
imagesc(cpu_u8(:,:)); axis equal tight
subplot(222)
imagesc(log_u8(:,:)); axis equal tight
subplot(223)
imagesc(cpu_u8((240-10):(240+10),(320-10):(320+10))); axis equal tight
subplot(224)
imagesc(log_u8((240-10):(240+10),(320-10):(320+10))); axis equal tight
colormap(gray)


%% --- helpers
function [fx_hat, fy_hat, dmin] = local_fft_peak(Ilin, pixPerDeg, fxCand, fyCand)
    I0 = Ilin - mean(Ilin(:));
    F  = fftshift(abs(fft2(I0)));
    [h,w] = size(I0);
    fx_axis = ((1:w) - (w+1)/2) * (pixPerDeg / w);
    fy_axis = -((1:h) - (h+1)/2) * (pixPerDeg / h);
    [FX, FY] = meshgrid(fx_axis, fy_axis);
    [~, iMax] = max(F(:)); [py, px] = ind2sub([h w], iMax);
    fx_hat = FX(py, px); fy_hat = FY(py, px);

    dmin = NaN;
    if nargin >= 4 && ~isempty(fxCand) && ~isempty(fyCand)
        fxCand = fxCand(:); fyCand = fyCand(:);
        dplus  = hypot(fx_hat - fxCand, fy_hat - fyCand);
        dminus = hypot(fx_hat + fxCand, fy_hat + fyCand);
        dmin   = min([dplus; dminus]);
        dmin   = min(dmin);
    end
end

function [Iu8, Ilin] = local_render_with_shift(hp, dx_deg, dy_deg)
    % Recompute on a shifted grid, leaving hp object untouched:
    [h,w] = size(hp.Xdeg);
    Xs = hp.Xdeg + dx_deg;
    Ys = hp.Ydeg + dy_deg;
    acc = zeros(h,w);
    for j = 1:hp.K
        acc = acc + hp.current.amp(j) .* ...
            sin( 2*pi*( hp.current.fx(j).*Xs + hp.current.fy(j).*Ys ) ...
                 + hp.current.phase(j) );
    end
    Ilin = hp.bgGrey + acc;
    Ilin = min(max(Ilin,0),1);
    Iu8 = uint8(round(Ilin*255));
end

function out = tern(cond,a,b),
if cond, out=a;
else, out=b;
end
end
