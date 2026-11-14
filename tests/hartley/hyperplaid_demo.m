function hyperplaid_phaseball_demo(viz_mode, make_movie)
% HYPERPLAID_PHASEBALL_DEMO
% Full-field static hyperplaid generator + (f_x, f_y, phase) visualizations.
%
% Usage:
%   hyperplaid_phaseball_demo                % defaults: rotate + no movie
%   hyperplaid_phaseball_demo('rotate',1)    % rotate view + export spin movie
%   hyperplaid_phaseball_demo('torus',0)     % torus view
%   hyperplaid_phaseball_demo('layered',0)   % layered phase strata view
%
% Declan-friendly defaults: 6 orientations, 5 SF, K=6, 8 phase bins, 200 ms/frame.

if nargin < 1 || isempty(viz_mode),   viz_mode   = 'rotate'; end   % 'rotate'|'torus'|'layered'
if nargin < 2 || isempty(make_movie), make_movie = 0;        end

%% ---------------- Parameters ----------------
rng(0);                          % reproducible

% Geometry / units
W = 512; H = 512;                % pixels
ppd = 60;                        % pixels/degree (set to your rig)
x_deg = ((1:W) - (W+1)/2) / ppd; % deg
y_deg = ((1:H) - (H+1)/2) / ppd;
[Xdeg, Ydeg] = meshgrid(x_deg, y_deg);

% Carrier bank
%orient_deg = 0:30:150;           % 6 orientations (0..150)
orient_deg = 0:15:165;           % 12 orientations (0..150)
O = numel(orient_deg);
sf_center = 3;                   % cycles/deg (tune per unit)
octaves   = 2;                   % total span
S         = 5;                   % # SFs
sfs_cpd   = sf_center * 2.^linspace(-octaves/2, octaves/2, S);

% Phase alphabet
M        = 4;                              % # phases
phi_set  = (0.5:M-.5) * (2*pi/M);             % 0,45,...,315 deg
% phi_set  = (0:M-1) * (2*pi/M);             % 0,45,...,315 deg
% phi_set  = (1:M) * (2*pi/M);             % 0,45,...,315 deg

% Frame synthesis
K          = 6;                             % components per frame
targetRMS  = 0.2;                           % post-normalization RMS
A          = 1;                             % base amplitude (pre-normalization)
T_montage  = 12;                            % frames to show in montage

% Phase cloud accumulator
T_cloud          = 300;                     % frames to accumulate for the cloud
points_per_frame = 200;                     % top-N FFT bins per frame (within mask)
ring_rel_width   = 0.10;                    % ±10% around each SF ring
use_upper_half   = true;                    % avoid Hermitian duplicates

% Visualization toggles
overlay_pair_markers = false;               % set true and edit 'pairMarks' below
export_still         = true;                % save phase ball PNG
whiten_by_radial     = true;                % divide FFT power by radial mean
view_az_el           = [42, 24];            % default 3D view

% Movie settings
spin_step_deg = 2;  spin_frames = 360/spin_step_deg;  fps = 30;

%% ---------------- Precompute carriers & bases ----------------
C = O * S;
carriers = struct('theta', [], 'sf', [], 'kx', [], 'ky', []);
idx = 0;
for oi = 1:O
    th = deg2rad(orient_deg(oi));
    for si = 1:S
        idx = idx + 1;
        sf = sfs_cpd(si);
        carriers(idx).theta = th;
        carriers(idx).sf    = sf;
        carriers(idx).kx    =  sf * cos(th);
        carriers(idx).ky    =  sf * sin(th);
    end
end

cosBasis = zeros(H, W, C, 'single');
sinBasis = zeros(H, W, C, 'single');
for c = 1:C
    phase0 = 2*pi*(carriers(c).kx*Xdeg + carriers(c).ky*Ydeg);
    cosBasis(:,:,c) = cos(phase0);
    sinBasis(:,:,c) = sin(phase0);
end

%% ---------------- Quick montage (sanity check) ----------------
frames = zeros(H, W, T_montage, 'single');
for t = 1:T_montage
    frames(:,:,t) = make_hyperplaid_frame();
end

figure('Color','w','Name','Hyperplaid frames');
nCol = 4; nRow = ceil(T_montage / nCol);
tiledlayout(nRow, nCol, 'Padding','compact','TileSpacing','compact');
for t = 1:T_montage
    nexttile;
    imagesc(frames(:,:,t), [-0.4 0.4]); colormap(gray); axis image off;
    title(sprintf('Frame %d', t), 'FontSize', 9);
end

%% ---------------- Frequency grid (cpd) ----------------
fx_pix = (-W/2:(W/2-1)) / W;         % cycles/pixel
fy_pix = (-H/2:(H/2-1)) / H;
[FX_pix, FY_pix] = meshgrid(fx_pix, fy_pix);
FX = FX_pix * ppd;                   % cycles/deg
FY = FY_pix * ppd;
R  = hypot(FX, FY);
fNyq = ppd/2;

% Half-plane to avoid mirror
halfMask = true(size(FX));
if use_upper_half
    halfMask = FY >= 0;
    halfMask(H/2+1, W/2+1) = false; % drop DC
end

% Thin ring mask around SF bank
ringMask = false(size(R));
for sf = sfs_cpd
    ringMask = ringMask | (abs(R - sf) <= (ring_rel_width * sf));
end
maskCloud = ringMask & halfMask & (R > 0) & (R <= fNyq);

%% ---------------- Phase cloud accumulation ----------------
cloud_fx = []; cloud_fy = []; cloud_phase = []; cloud_pow = [];

for t = 1:T_cloud
    acc = make_hyperplaid_frame();
    F0  = double(acc) - mean(double(acc),'all');
    F   = fftshift(fft2(F0));
    P   = abs(F).^2 / numel(F0);          % power
    if whiten_by_radial
        nb = 200;
        edges = linspace(0, fNyq, nb+1);
        % --- Robust radial whitening (drop-in fix) ---
        nb    = 200;
        edges = linspace(0, fNyq, nb+1);
        
        % Precompute bin indices once (same size as R)
        idxb = discretize(R, edges);              % 1..nb or NaN
        
        % Valid pixels that have a bin
        valid = ~isnan(idxb);
        
        % Sum and count per radial bin (ignore NaNs)
        radSum = accumarray(idxb(valid), P(valid), [nb 1], @sum, 0);
        radCnt = accumarray(idxb(valid), 1,        [nb 1], @sum, 0);
        
        % Mean power per bin; fill empties; avoid zeros
        radMean = radSum ./ max(radCnt, 1);
        % Fill any remaining 0/NaN by nearest non-empty bin
        radMean(~isfinite(radMean) | radMean==0) = NaN;
        radMean = fillmissing(radMean, 'nearest');
        radMean(radMean==0 | ~isfinite(radMean)) = eps;
        
        % Build denominator image and whiten
        denom = ones(size(P));                    % default 1 outside bins (no op)
        denom(valid) = radMean(idxb(valid));
        P = P ./ denom;
        % --- end radial whitening ---

    end
    A2D = angle(F);                         % phase

    cand = find(maskCloud);
    [~, ord] = sort(P(cand), 'descend');
    keep = cand(ord(1:min(points_per_frame, numel(ord))));

    cloud_fx    = [cloud_fx; FX(keep)]; %#ok<AGROW>
    cloud_fy    = [cloud_fy; FY(keep)]; %#ok<AGROW>
    cloud_phase = [cloud_phase; A2D(keep)]; %#ok<AGROW>
    cloud_pow   = [cloud_pow; P(keep)]; %#ok<AGROW>
end

% Marker size/alpha by power
pow_norm = (cloud_pow - min(cloud_pow)) / max(eps, (max(cloud_pow)-min(cloud_pow)));
msz      = 6 + 24*sqrt(pow_norm);

%% ---------------- Phase-ball views ----------------
switch lower(viz_mode)
    case 'rotate'   % rotation about x-axis: y' = y cosφ, z' = y sinφ
        Xp = cloud_fx;
        Yp = cloud_fy .* cos(cloud_phase);
        Zp = cloud_fy .* sin(cloud_phase);
        zlab = 'f_y sin\phi';
        ylab = 'f_y cos\phi';
    case 'layered'  % layer z by sinφ; bias y so it stays >= 0
        shift_scale = 0.1 * median(cloud_fy(cloud_fy>0));
        Xp = cloud_fx;
        Yp = cloud_fy + shift_scale*(1 - cos(cloud_phase));
        Zp = shift_scale * sin(cloud_phase);
        zlab = 'phase layer';
        ylab = 'f_y + bias';
    case 'torus'    % torus around orientation ring (keeps θ fixed)
        r  = hypot(cloud_fx, cloud_fy);
        th = atan2(cloud_fy, cloud_fx);
        rho = 0.15 * median(r(r>0));   % minor radius
        Xp = (r + rho*cos(cloud_phase)) .* cos(th);
        Yp = (r + rho*cos(cloud_phase)) .* sin(th);
        Zp =  rho * sin(cloud_phase);
        zlab = 'minor circle';
        ylab = 'f_y (torus)';
    otherwise
        error('viz_mode must be rotate|layered|torus');
end

figure('Color','w','Name',['Phase cloud: ' viz_mode]);
scatter3(Xp, Yp, Zp, msz, wrapToPi(cloud_phase), 'filled', ...
         'MarkerFaceAlpha', 0.25, 'MarkerEdgeAlpha', 0.1);
colormap(hsv); colorbar; caxis([-pi pi]);
xlabel('f_x (cpd)'); ylabel(ylab); zlabel(zlab);
title(['Phase as ' viz_mode]); grid on; axis vis3d; view(view_az_el(1), view_az_el(2));

% Context: base rings + orientation spokes + SF labels
hold on;
% Spokes
for th = orient_deg
    ang = deg2rad(th);
    L = max(sfs_cpd)*1.05;
    plot3([0 L*cos(ang)], [0 L*sin(ang)], [0 0], 'k--', 'LineWidth', 0.6);
end
% Rings + labels at z=0
ang = linspace(0, pi, 361);  % upper half-plane
for sf = sfs_cpd
    x0 = sf*cos(ang); y0 = sf*sin(ang);
    plot3(x0, y0, zeros(size(ang)), 'k:', 'LineWidth', 0.7);
    text(sf, 0, 0.02*max(sfs_cpd), sprintf('%.1f cpd', sf), 'FontSize', 8, 'HorizontalAlignment','left');
end

% Optional Δφ probe pair markers on base plane
if overlay_pair_markers
    pairMarks = [ ...
        sfs_cpd(2)  0;   % (sf, ori-deg)
        sfs_cpd(4) 90];
    for ii = 1:size(pairMarks,1)
        sf = pairMarks(ii,1); deg = pairMarks(ii,2);
        plot3(sf*cosd(deg), sf*sind(deg), 0, 'ro', 'MarkerSize', 6, 'LineWidth', 1.2);
    end
end

% Export still & spin movie
if export_still
    exportgraphics(gcf, ['phaseball_' viz_mode '.png'], 'Resolution', 300);
end
if make_movie
    v = VideoWriter(['phaseball_' viz_mode '_spin.mp4'], 'MPEG-4');
    v.FrameRate = fps; open(v);
    for az = 0:spin_step_deg:360-spin_step_deg
        view(az, view_az_el(2)); drawnow; writeVideo(v, getframe(gcf));
    end
    close(v);
end

%% ---------------- Nested: synthesize one frame ----------------
    function acc = make_hyperplaid_frame()
        chosen = randperm(C, K);                 % K distinct carriers
        phases = phi_set(randi(M, [1 K]));       % discrete phases
        signs  = randi(2, [1 K])*2 - 3;          % {-1,+1}
        acc = zeros(H, W, 'single');
        amp = A / sqrt(K);
        for j = 1:K
            cIdx = chosen(j);
            cb = cos(phases(j)); sb = sin(phases(j));
            acc = acc + amp * signs(j) * (cb * cosBasis(:,:,cIdx) - sb * sinBasis(:,:,cIdx));
        end
        r = rms(acc(:)); if r>0, acc = acc * (targetRMS / r); end
        acc = max(min(acc, 1), -1);              % safety clamp
    end
end
