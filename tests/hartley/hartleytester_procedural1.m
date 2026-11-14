% NOTE: Using the canonical Hartley cas convention:
%   I(x,y) = sin(2π(fx·x + fy·y) + π/4)
% which equals (cos(2π(...)) + sin(2π(...))) / √2.
% All textures in hartleyplaid_static are baked with +π/4.

InitializeMatlabOpenGL
% Setup a small test window:
Screen('Preference','SkipSyncTests',1);
S = MarmoViewRigSettings;  % your rig helper

%FOR TESTING ONLY
S.gamma=2.2;
inver_gamma=1/S.gamma;
A = marmoview.openScreen(S);

% Build a hyperplaid in PROCEDURAL mode (fast):
hp = stimuli.hartleyplaid_procedural(A.window, ...
    'screenRect', S.screenRect, ...
    'pixPerDeg', S.pixPerDeg, ...
    'frameRate', 60, ...
    'spatialFrequencies', 2, ...
    'K', 2, ...
    'updateEveryNFrames',1,...
    'ns', 4, ... 
    'contrast', 0.4);

        % force dense lattice
hp.equalStride = true;  % allow anisotropy
hp.FmaxX_cpd = 8;    % keep your usual max SF
hp.FmaxY_cpd = 8;

hp.bankReady = false;
hp.bank = hp.buildBank();  % rebuild with stride=1 full lattice
fprintf('Total atoms in bank: %d\n', numel(hp.bank));
fx = [hp.bank.fx]; fy = [hp.bank.fy];
fprintf('Coverage fx=[%.2f,%.2f], fy=[%.2f,%.2f] c/deg; count=%d\n', ...
        min(fx),max(fx),min(fy),max(fy), numel(fx));


hp.beforeTrial();
hp.stimValue = 1;

for f = 1:3
    hp.beforeFrame();
    vbl = Screen('Flip', A.window);
    % Log numeric row:
    row = hp.currentLogRowNumeric(vbl);
    % store row as needed in your protocol...



    %
    % After a Screen('Flip'), capture the on-screen image:
%     gpuFrame = mean(Screen('GetImage', A.window, S.screenRect, [], 0),3); % no float
    gpuFrame = mean(Screen('GetImage', A.window, S.screenRect, [], 1), 3);  % float [0..1]
    cpuFrame = double(hp.getImage(S.screenRect, 1)) / 255;                  % match scale
% mae = mean(abs(gpuFrame(:) - cpuFrame(:)));

    gpu_beforegamma=gpu.^inver_gamma;
    % CPU render the same frame:
    %cpuFrame = hp.getImage(S.screenRect, 1); % your hartleyplaid_static instance
    gammacpuFrame = 255*(double(cpuFrame).^inver_gamma)./255.^inver_gamma;
    ungammagpuFrame=256*(double(gpuFrame).^S.gamma)./255.^S.gamma;
    % CPU render the same frame:
    %cpuFrame = hp.getImage(S.screenRect, 1); % your hyperplaid_static instance

    % Compare mean absolute error (on a linearized pipeline they should match up to rounding):
    mae = mean(abs(double(gpuFrame(:)) - double(cpuFrame(:))));
    fprintf('GPU/CPU MAE: %.3f (expected ~<= 1 LSB)\n', mae);

    hp.afterFrame(); %update
    %
    figure(2)
    subplot(221)
    imagesc(gpuFrame(:,:)); axis equal tight
    subplot(222)
    imagesc(cpuFrame(:,:)); axis equal tight
    subplot(223)
    imagesc(gpuFrame((240-10):(240+10),(320-10):(320+10))); axis equal tight
    subplot(224)
    imagesc(cpuFrame((240-10):(240+10),(320-10):(320+10))); axis equal tight
    colormap(gray)

    pause(1)
end


%%
% hp.beforeTrial();
% for f=1:10
%     hp.beforeFrame();
%     vbl = Screen('Flip', A.window);
% 
%     gpu = mean(Screen('GetImage', hp.offwin, S.screenRect, [], 1),3);
%     cpu = double(hp.getImage(S.screenRect,1))/255;
%     mae = mean(abs(gpu(:)-cpu(:)));
%     fprintf('GPU/CPU MAE: %.4f\n', mae);   % expect a few LSBs at most
% 
%     hp.afterFrame();
% end


% %%
% %function test_HartleyShader_sign(winPtr)
%     % Known conditions
%     kx = 2; ky = 0; amp = 1.0;
%     bg = 0.5;
% 
%     % Background first
%     Screen('FillRect', hp.winPtr, bg);
%     Screen('BeginOpenGL', hp.winPtr);
%     glEnable(hex2dec('0BE2'));                    % GL_BLEND
%     glBlendFunc(1, 1);                            % GL_ONE, GL_ONE
% 
%     % Use your existing program handle
%     %global hp.shader
%     glUseProgram(hp.shader.program);
%     glUniform1f(hp.shader.loc_kx, kx);
%     glUniform1f(hp.shader.loc_ky, ky);
%     glUniform1f(hp.shader.loc_amp, abs(amp));
%     glUniform1f(hp.shader.loc_sign, sign(amp));
% 
%     % Draw full-screen quad
%     glBegin(hex2dec('0007'));                     % GL_QUADS
%         glVertexAttrib2f(hp.shader.loc_position, -1,-1);
%         glVertexAttrib2f(hp.shader.loc_position,  1,-1);
%         glVertexAttrib2f(hp.shader.loc_position,  1, 1);
%         glVertexAttrib2f(hp.shader.loc_position, -1, 1);
%     glEnd;
%     glUseProgram(0);
%     Screen('EndOpenGL', hp.winPtr);
%     Screen('Flip', hp.winPtr);
% 
%     % Grab the rendered frame and inspect its mean
%     img = mean(Screen('GetImage', hp.winPtr),3);
%     fprintf('Shader mean (amp=%+.1f): %.3f  [expected ~0.5]\n', amp, mean(img(:)));
% 
%     % Repeat for negative amplitude
%     Screen('FillRect', hp.winPtr, bg);
%     Screen('BeginOpenGL', hp.winPtr);
%     glUseProgram(hp.shader.program);
%     glUniform1f(hp.shader.loc_kx, kx);
%     glUniform1f(hp.shader.loc_ky, ky);
%     glUniform1f(hp.shader.loc_amp, abs(amp));
%     glUniform1f(hp.shader.loc_sign, -sign(amp));
%     glBegin(hex2dec('0007'));
%         glVertexAttrib2f(hp.shader.loc_position, -1,-1);
%         glVertexAttrib2f(hp.shader.loc_position,  1,-1);
%         glVertexAttrib2f(hp.shader.loc_position,  1, 1);
%         glVertexAttrib2f(hp.shader.loc_position, -1, 1);
%     glEnd;
%     glUseProgram(0);
%     Screen('EndOpenGL', hp.winPtr);
%     Screen('Flip', hp.winPtr);
%     img2 = mean(Screen('GetImage', hp.winPtr),3);
%     fprintf('Shader mean (amp=%+.1f): %.3f  [expected ~0.5]\n', -amp, mean(img2(:)));
% 
%     fprintf('Difference in mean between +amp and -amp = %.3f (should be ~0)\n', ...
%             mean(img(:)) - mean(img2(:)));
% %end




%%
n = 10; maes = zeros(1,n);
for k = 1:n
    [gpu,cpu] = grab_frames(hp,S);
    maes(k) = mean(abs(double(gpu(:)) - double(cpu(:))));
end
fprintf('GPU/CPU MAE (mean±sd): %.3f ± %.3f LSB\n', mean(maes), std(maes));


%%
% Force K=1, pick a specific atom
hp.K = 1;
hp.sampleComponents();
j = 1;  % only one

% The four cas phase variants (+π/4, +3π/4, −π/4, −3π/4)
phases = [ pi/4,  3*pi/4, -pi/4, -3*pi/4];   % the four cas phases (±π/4 and ±3π/4)
amps   = [ 1,      1,     -1,     -1     ] * (hp.contrast / sqrt(hp.K));

% CPU-only eval at center pixel (exactly centered grid!)
w = RectWidth(hp.screenRect); h = RectHeight(hp.screenRect);
cx = (w+1)/2; cy = (h+1)/2;
bg = 127;
for t = 1:4
    phi = phases(t); a = amps(t);
    center = bg + 255*(a * sin(phi));
    fprintf('phi=% .2f rad : center = %.2f LSB (bg=%d)\n', phi, center, bg);
end

%%
hp.K = 2;
hp.sampleComponents();

% Pick one base atom index from the +k half-plane:
C = numel(hp.bank)/2;                   % base half
i = randi(C);
hp.current.idx = [i i];                 % same texture twice
hp.current.phase = [+pi/4 +pi/4];       % same phase family (cas convention)
hp.current.fx=[hp.current.fx hp.current.fx];
hp.current.fy=[hp.current.fy hp.current.fy];
hp.current.amp   = [ hp.contrast/sqrt(2), -hp.contrast/sqrt(2) ]; % equal & opposite
hp.frameUpdate = 1;

[gpu,cpu] = grab_frames(hp,S);
bg = 127;
dev = mean(abs(double(gpu(:))-bg));
fprintf('Cancel test: mean |dev| = %.3f LSB (want ~0)\n', dev);

%% RMS vs. K (tight-frame property ⇒ ~constant)
%Because each component has amp = contrast/√K and the sine RMS is 1/√2, the total RMS should be ≈ contrast/√2 (independent of K).
bg = 127;
Ks = [1 2 4 6 8 12];
for K = Ks
    hp.K = K; hp.sampleComponents();
    [gpu,~] = grab_frames(hp,S);
    r = rms_img(gpu, bg);
    r_theory = (hp.contrast/sqrt(2))*255;
    fprintf('K=%2d: RMS = %.2f LSB  (theory ~ %.2f)\n', K, r, r_theory);
end
%% Mean luminance stability
hp.K = 6;  n = 12; means = zeros(1,n);
for k=1:n
    hp.sampleComponents();
    [gpu,~] = grab_frames(hp,S);
    means(k) = mean_img(gpu);
end
fprintf('Mean luminance: %.2f ± %.2f LSB (bg=%d)\n', mean(means), std(means), 127);


%% −k partner integrity
C = numel(hp.bank)/2;
ii = randi(C, [1 10]);
ok = true;
for i = ii
    j = hp.bank(i).opp;
    ok = ok & (abs(hp.bank(j).fx + hp.bank(i).fx) < 1e-12) ...
           & (abs(hp.bank(j).fy + hp.bank(i).fy) < 1e-12) ...
           & (hp.bank(j).opp == i);
end
assert(ok, 'Opposite -k not a perfect negation or pairing failed.');
disp('opp mapping OK.');




%% --- Gram matrix check: inner products of all atoms
fprintf('\n--- Orthonormality check (Gram matrix) ---\n');

% Build all atoms as unit-contrast, mean-zero Hartley functions
w = RectWidth(hp.screenRect);
h = RectHeight(hp.screenRect);
[Xdeg, Ydeg] = meshgrid((1:w)-(w+1)/2, (1:h)-(h+1)/2);
Xdeg =  Xdeg / hp.pixPerDeg;
Ydeg = -Ydeg / hp.pixPerDeg;

nC = numel(hp.bank);
atoms = zeros(h, w, nC);

for i = 1:nC
    fx = hp.bank(i).fx;
    fy = hp.bank(i).fy;
    % canonical cas phase (+π/4 for +k, -π/4 for −k)
    if fx>0 || (fx==0 && fy>0)
        phi = +pi/4;
    else
        phi = -pi/4;
    end
    atoms(:,:,i) = sin(2*pi*(fx*Xdeg + fy*Ydeg) + phi);
end

% Flatten and normalize
A_ = reshape(atoms, [], nC);
G = (A_' * A_) / numel(Xdeg);  % normalized inner products

offdiag = G - diag(diag(G));
fprintf('Mean |offdiag| = %.2e   (want ~<1e-12)\n', mean(abs(offdiag(:))));
fprintf('Max  |offdiag| = %.2e\n', max(abs(offdiag(:))));
fprintf('Diag range: %.6f ± %.6f\n', mean(diag(G)), std(diag(G)));

%%

% only +k half of the bank
nC = numel(hp.bank)/2;
atoms = zeros(h, w, nC);
for i = 1:nC
    fx = hp.bank(i).fx; fy = hp.bank(i).fy;
    phi = +pi/4;  % +k half uses +π/4
    atoms(:,:,i) = sin(2*pi*(fx*Xdeg + fy*Ydeg) + phi);
end

A_ = reshape(atoms, [], nC);
A_ = bsxfun(@rdivide, A_, sqrt(sum(A_.^2,1)));  % columns to unit norm
G = (A_'*A_);                                   % diag ~ 1, offdiag small
offdiag = G - diag(diag(G));
fprintf('Mean |offdiag| = %.2e, Max |offdiag| = %.2e (half-plane, unit-norm)\n', ...
        mean(abs(offdiag(:))), max(abs(offdiag(:))));

%% --- Sum-of-squares (tight-frame) flatness
fprintf('\n--- Tight-frame flatness (sum of squares) ---\n');

S = sum(atoms.^2, 3);
flatness = std(S(:)) / mean(S(:));
fprintf('Flatness ratio std/mean = %.2e (want ~0)\n', flatness);

% Optional: visualize
figure(99); imagesc(S); axis equal tight; colormap(gray);
title(sprintf('Sum of squares across %d atoms (std/mean=%.2e)', nC, flatness));
colorbar;





%% FFT and shift tests

% Assumes: hp is your object; A.window is open; logs reflect drawn k & amps
% Force a single known component (no randomness)
hp.K = 1;
hp.sampleComponents();  % uses your scheme A logs: current.idx, fx, fy, amp, phase
hp.beforeFrame(); vbl = Screen('Flip', A.window); %#ok<NASGU>
gpu = mean(Screen('GetImage', A.window, hp.screenRect, [], 0),3); % uint8
dev = double(gpu)/255 - hp.bgGrey; % mean-zero [−.5,+.5]

% FFT in cyc/deg axes:
[h,w] = size(dev);
Wdeg = RectWidth(hp.screenRect)/hp.pixPerDeg;
Hdeg = RectHeight(hp.screenRect)/hp.pixPerDeg;
Fx = (-floor(w/2):ceil(w/2)-1)/Wdeg;   % cycles/deg
Fy = (-floor(h/2):ceil(h/2)-1)/Hdeg;   % cycles/deg

F = fftshift(fft2(dev));
mag = abs(F); mag(round(h/2+1), round(w/2+1)) = 0;   % zero out DC just in case
[~,mx] = max(mag(:));
[py, px] = ind2sub(size(mag), mx);
fx_hat = Fx(px); fy_hat = Fy(py);

% Expected is either +k OR −k (both present in Fourier of a real image):
fx_log = hp.current.fx(1); fy_log = hp.current.fy(1);
% cands = [fx_log,  fy_log;
%         -fx_log, -fy_log];
% expected peaks for a real image under image-row-down coords:
cands = [ fx_log,  fy_log;     % model (+,+)
            -fx_log, -fy_log;     % model (-,-)
             fx_log, -fy_log;     % image (+,-) due to row-down
            -fx_log,  fy_log];    % image (-,+)

d = hypot(fx_hat - cands(:,1), fy_hat - cands(:,2));
fprintf('FFT peak (%.3f, %.3f) c/deg vs bank ±(%.3f, %.3f) — Δ=%.3g\n', ...
        fx_hat, fy_hat, fx_log, fy_log, min(d));

% Draw a multi-K frame first (hp.K already set), then:
gpu = mean(Screen('GetImage', A.window, hp.screenRect, [], 0),3);
dev = double(gpu)/255 - hp.bgGrey;

[h,w] = size(dev);
Wdeg = RectWidth(hp.screenRect)/hp.pixPerDeg;
Hdeg = RectHeight(hp.screenRect)/hp.pixPerDeg;
Fx = (-floor(w/2):ceil(w/2)-1)/Wdeg;
Fy = (-floor(h/2):ceil(h/2)-1)/Hdeg;

F = fftshift(fft2(dev));
mag = abs(F); mag(round(h/2+1), round(w/2+1)) = 0;

% pull top 2K peaks:
K = hp.K;
[vals, idxs] = maxk(mag(:), min(2*K, numel(mag)-1));
[py, px] = ind2sub(size(mag), idxs);
peaks = [Fx(px(:))', Fy(py(:))'];

% Build expected set {±k_j}:
fx_log = hp.current.fx(:);
fy_log = hp.current.fy(:);
% expected = [fx_log,  fy_log; -fx_log, -fy_log];  % (2K × 2)
% expected peaks for a real image under image-row-down coords:
expected = [ fx_log,  fy_log;     % model (+,+)
            -fx_log, -fy_log;     % model (-,-)
             fx_log, -fy_log;     % image (+,-) due to row-down
            -fx_log,  fy_log];    % image (-,+)
% greedy match: each FFT peak matched to nearest expected
tol = 0.05;  % c/deg, tweak if your Wdeg/Hdeg are small
used = false(size(expected,1),1);
miss = 0;
for i = 1:size(peaks,1)
    d2 = hypot(peaks(i,1) - expected(:,1), peaks(i,2) - expected(:,2));
    d2(used) = inf;
    [m, j] = min(d2);
    miss = miss + (m > tol);
    used(j) = true;
end
fprintf('Multi-K FFT: matched %d/%d peaks within %.3f c/deg (unmatched=%d)\n', ...
        2*K - miss, 2*K, tol, miss);
%% Shift-vs-phase (GPU draw rect shift ↔ predicted phase advance
% Choose a shift in px (integer keeps resampling exact)
dx_px = 7;  dy_px = -5;
pd = hp.pixPerDeg;

% 1) Base frame
hp.sampleComponents();
hp.beforeFrame(); vbl = Screen('Flip', A.window); %#ok<NASGU>
gpu0 = mean(Screen('GetImage', A.window, hp.screenRect, [], 0),3);
dev0 = double(gpu0)/255 - hp.bgGrey;

% 2) Shifted frame: draw same atoms but move dstrect by (dx_px,dy_px)
dst = repmat(hp.screenRect(:), 1, hp.K);
dst = dst + repmat([dx_px; dy_px; dx_px; dy_px], 1, hp.K);
scale = hp.current.amp(:)';
Screen('FillRect', A.window, hp.bgGrey);
Screen('BlendFunction', A.window, GL_ONE, GL_ONE);
Screen('DrawTextures', A.window, double(hp.texHandles(hp.current.idx)), [], dst, 0, [], [], ...
       [scale; scale; scale; ones(1,hp.K)]');  % modulateColor
Screen('BlendFunction', A.window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
vbl = Screen('Flip', A.window); %#ok<NASGU>
gpuS = mean(Screen('GetImage', A.window, hp.screenRect, [], 0),3);
devS = double(gpuS)/255 - hp.bgGrey;

% 3) CPU prediction for the shift (phase advance)
w = RectWidth(hp.screenRect);  h = RectHeight(hp.screenRect);
[xPix, yPix] = meshgrid((1:w)-(w+1)/2, (1:h)-(h+1)/2);
Xdeg =  xPix / pd;  Ydeg = -yPix / pd;

acc0 = zeros(h,w);
accS = zeros(h,w);
for j=1:hp.K
    fx = hp.current.fx(j); fy = hp.current.fy(j);
    phi0 = -pi/4;  % baked
    a   = hp.current.amp(j);

%     dphi = 2*pi*( fx*(dx_px/pd) - fy*(dy_px/pd) );
    dphi = 2*pi*( -fx*(dx_px/pd) + fy*(dy_px/pd) );
    acc0 = acc0 + a * sin(2*pi*(fx*Xdeg + fy*Ydeg) + phi0);
    accS = accS + a * sin(2*pi*(fx*Xdeg + fy*Ydeg) + phi0 + dphi);
end
pred0 = acc0;
predS = accS;

% Compare GPU vs CPU (LSB)
mae0 = mean(abs(dev0(:) - pred0(:)))*255;
maeS = mean(abs(devS(:) - predS(:)))*255;
fprintf('Shift-vs-phase MAE: base=%.3f LSB, shifted=%.3f LSB\n', mae0, maeS);







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
%% ------------------ helpers
function [gpu8,cpu8] = grab_frames(hp, S)
    % Draw once on GPU and grab image (LDR 8-bit), then CPU render
    hp.beforeFrame();
    vbl = Screen('Flip', hp.winPtr); %#ok<NASGU>
    gpu8 = mean(Screen('GetImage', hp.winPtr, S.screenRect, [], 0),3);
    cpu8 = hp.getImage(S.screenRect, 1);
    hp.afterFrame();
end

function rmsLSB = rms_img(I8, bg)
    D = double(I8) - bg;
    rmsLSB = sqrt(mean(D(:).^2));
end

function m = mean_img(I8), m = mean(I8(:)); end
