function demo_hyperplaid_cpu_quick()
% Minimal CPU-only “superimposed hyperplaid” demo (no PTB needed).
% K gratings per frame, random orientations & SF rings, Hartley-ish phase (±pi/4).

Wdeg = 10; Hdeg = 8;            % field of view (deg)
ppd  = 60;                      % pixels/deg
K    = 6;                       % components/frame
rings_cpd = 3*2.^linspace(-1,1,5);  % 5 SF rings ~ [1.5..6] cpd
nFrames = 9;                    % how many example frames to plot
contrast = 0.4;                 % per-frame RMS target (approx)
amp = contrast / sqrt(K);       % per-component amplitude

% Pixel grids in degrees (y up)
nx = round(Wdeg*ppd); ny = round(Hdeg*ppd);
[xpix, ypix] = meshgrid( (1:nx) - nx/2, (1:ny) - ny/2 );
Xdeg =  xpix / ppd; 
Ydeg = -ypix / ppd;

figure('Color','w','Name','CPU Hyperplaid Demo'); colormap(gray);
for f = 1:nFrames
    acc = zeros(ny,nx);
    ori_deg = rand(1,K)*180;                           % random orientations (0..180)
    sf_cpd  = rings_cpd(randi(numel(rings_cpd),[1,K]));% random SF rings
    phiBase = (rand(1,K)>0)*pi + (-pi/4);              % Hartley cas ± pi
    for j = 1:K
        th  = deg2rad(ori_deg(j));
        fx  = sf_cpd(j)*cos(th);
        fy  = sf_cpd(j)*sin(th);
        acc = acc + sin( 2*pi*(fx.*Xdeg + fy.*Ydeg) + phiBase(j) );
    end
    I = 0.5 + amp*acc;                         % add gray bg (0.5)
    I = uint8(255*min(max(I,0),1));
    subplot(3,3,f); imagesc(I); axis image off;
    title(sprintf('Frame %d  |  K=%d',f,K));
end
end
