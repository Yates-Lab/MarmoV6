classdef hartleyplaid_static < stimuli.stimulus
% Full-field static Hartley hartleyplaid (K gratings/frame, no drift).
% Pixel-accurate: each lattice atom is pre-rendered to a texture with
% known [fx, fy] in cycles/deg. No per-draw rotations are used.
%
% Per-frame log row (numeric):
%   [t, K, fx(1:K), fy(1:K), amp(1:K), idx(1:K)]
%
% Analysis tip (gaze correction per frame):
%   phi_ret = phiSent + 2*pi*(fx*dx + fy*dy);  z = amp .* exp(1i*phi_ret);
% no longer using phiSent, all phases are baked into textures as =pi/4
% I(x,y) = bgGrey + sum_j( amp(j) * sin( 2*pi*(fx(idx(j))*X + fy(idx(j))*Y) + pi/4 ) )

    properties
        % --- display ---
        winPtr
        screenRect
        pixPerDeg
        bgGrey = 0.5;
        linearize = true

        % --- design ---
        maxSF double = 8
        spatialFrequencies_cpd double = 3 * 2.^linspace(-1,1,5)  % kept for convenience
        K double = 6
        contrast double = 0.4

        % --- timing ---
        frameRate double = 60
        updateEveryNFrames double = []

        % --- geometry ---
        position double = []
        diameter double = inf

        % --- Hartley lattice parameters (TIGHT rectangular sublattice) ---
        useHartleyLattice logical = true
        hartleyKmax double = []              % (unused in new mode; kept for back-compat)
        
        % NEW / CHANGED:
        FmaxX_cpd double = 8                 % rectangular cap in cyc/deg (|fx|<=FmaxX)
        FmaxY_cpd double = 8                 % rectangular cap in cyc/deg (|fy|<=FmaxY)
        strideKx double = 32                 % choose sx, sy; sx/sy ≈ Wdeg/Hdeg
        strideKy double = 18

        uniquePerFrame logical = true
        bank
        texHandles
        bankReady logical = false

        % --- runtime state ---
        frameUpdate double = 0
        current
        %rng, don't set here, its inherited from the stimuli.stimulus class

        oldmaximumvalue
        oldclampcolors 
        oldapplyToDoubleInputMakeTexture
    end

    methods
        function obj = hartleyplaid_static(winPtr, varargin)
            obj = obj@stimuli.stimulus();
            obj.winPtr = winPtr;

            % NEEDS DISABLED CLAMPING OR TWICE AS MANY TEXTURES 
            % Use OpenGL’s native [0..1] color range and DISABLE clamping:
            [obj.oldmaximumvalue, obj.oldclampcolors, obj.oldapplyToDoubleInputMakeTexture]=Screen('ColorRange', winPtr, 1, 0);

            ip = inputParser();
            ip.addParameter('screenRect', []);
            ip.addParameter('pixPerDeg', 60);
            ip.addParameter('frameRate', 60);
            ip.addParameter('spatialFrequencies', obj.spatialFrequencies_cpd);
            ip.addParameter('K', obj.K);
            ip.addParameter('contrast', obj.contrast);
            ip.addParameter('updateEveryNFrames', []);
            ip.addParameter('useHartleyLattice', true);
            ip.addParameter('hartleyKmax', []);
            % NEW / CHANGED:
            ip.addParameter('maxSF', obj.maxSF);

            ip.addParameter('uniquePerFrame', true);
            ip.addParameter('bgGrey', obj.bgGrey);
            ip.addParameter('linearize', true);

            ip.parse(varargin{:});

            obj.screenRect             = ip.Results.screenRect;
            obj.pixPerDeg              = ip.Results.pixPerDeg;
            obj.frameRate              = ip.Results.frameRate;
            obj.spatialFrequencies_cpd = ip.Results.spatialFrequencies;
            obj.K                      = ip.Results.K;
            obj.contrast               = ip.Results.contrast;
            obj.useHartleyLattice      = ip.Results.useHartleyLattice;
            obj.hartleyKmax            = ip.Results.hartleyKmax;
            % NEW / CHANGED:
            obj.FmaxX_cpd              = ip.Results.maxSF;
            obj.FmaxY_cpd              = ip.Results.maxSF;


            obj.uniquePerFrame         = ip.Results.uniquePerFrame;
            obj.bgGrey                 = 0.5;%ip.Results.bgGrey;
            obj.linearize              = ip.Results.linearize;

            if isempty(ip.Results.updateEveryNFrames)
                obj.updateEveryNFrames = ceil(obj.frameRate/60); % ~5 Hz
            else
                obj.updateEveryNFrames = ip.Results.updateEveryNFrames;
            end


            Wdeg =  (obj.screenRect(3)-obj.screenRect(1)) / obj.pixPerDeg;%51.344; 
            Hdeg =  (obj.screenRect(4)-obj.screenRect(2)) / obj.pixPerDeg;%28.881;

            [sx, sy, info] = pickHartleyStridesFromNs(Wdeg, Hdeg, obj.FmaxX_cpd, obj.FmaxY_cpd, 25);
            obj.strideKx = sx; obj.strideKy = sy;
            fprintf('Strides picked: sx=%d, sy=%d, nx=%d, ny=%d, N=%d, fx_step=%.3f, fy_step=%.3f\n', ...
                sx, sy, info.nx, info.ny, info.N_total, info.fx_step, info.fy_step);

            obj.bank = obj.buildBank();            % NEW sublattice
            obj.texHandles = obj.buildTextures();  % pre-render
            obj.bankReady = true;
        end

        function bank = buildBank(obj)
            Wdeg = RectWidth(obj.screenRect)/obj.pixPerDeg;
            Hdeg = RectHeight(obj.screenRect)/obj.pixPerDeg;

            % Integer-cycle bounds from rectangular cap (in cycles/deg):
            Kx_max = floor(Wdeg * obj.FmaxX_cpd);
            Ky_max = floor(Hdeg * obj.FmaxY_cpd);

            % Even stride sublattice including zeros; we'll drop DC and canonicalize:
            kx_vals = -Kx_max:obj.strideKx:Kx_max;
            ky_vals = -Ky_max:obj.strideKy:Ky_max;

            [KX, KY] = ndgrid(kx_vals, ky_vals);
            KX = KX(:); KY = KY(:);

            % Drop DC only:
            keep = ~(KX==0 & KY==0);
            KX = KX(keep); KY = KY(keep);

            % ---- Step 1: pick a canonical half-plane to avoid ±k duplicates
            keepHalf = (KX > 0) | (KX==0 & KY > 0);
            KXh = KX(keepHalf); KYh = KY(keepHalf);          % half-plane reps only

            % ---- Step 2: append their negatives to get full plane (+k and −k)
            KXp = [ KXh ; -KXh ];
            KYp = [ KYh ; -KYh ];

            % Visual units (cycles/deg):
            fx = KXp / Wdeg;
            fy = KYp / Hdeg;

            sf = hypot(fx, fy);
            th = atan2(fy, fx);

            % ---- Step 3: build opposite-index map (pairing +k <-> −k)
            nH = numel(KXh);
            opp = [(nH+1):(2*nH), 1:nH]';   % opp(i) gives partner row for i
            % NB: indices 1..nH are +k half-plane, (nH+1)..2nH are their negatives.

            % Build struct bank and store the partner index:
            bank = struct('fx', num2cell(fx), ...
                'fy', num2cell(fy), ...
                'sf', num2cell(sf), ...
                'th', num2cell(th), ...
                'ori', num2cell(rad2deg(mod(th, 2*pi))), ...
                'opp', num2cell(opp));
        end

        function texHandles = buildTextures(obj)
            % Precompute uint8 textures for each Hartley atom:
            % I(x,y) = sin(2π (fx X + fy Y) - π/4), mean ~127
            w = RectWidth(obj.screenRect);
            h = RectHeight(obj.screenRect);

            [xPix, yPix] = meshgrid( (1:w) - (w+1)/2, ...
                                     (1:h) - (h+1)/2 );
            
            Xdeg =  xPix / obj.pixPerDeg;
            Ydeg = -yPix / obj.pixPerDeg;

            nC = numel(obj.bank);
            texHandles = zeros(1, nC);

            for c = 1:nC
                fx = obj.bank(c).fx; fy = obj.bank(c).fy;
                
%                 if sign(fx)>0&&sign(fy)>0
                    phase = 2*pi*(fx.*Xdeg + fy.*Ydeg) + pi/4;  % Hartley cas for +k
%                 elseif sign(fx)<0&&sign(fy)<0
%                     phase = 2*pi*(fx.*Xdeg + fy.*Ydeg) + pi/4;  % Hartley cas for -k
%                 end

%                 Iu8 = uint8(round(127 + 127 * sin(phase)));
%                 texHandles(c) = Screen('MakeTexture', obj.winPtr, Iu8, 0, 0);

                % Build (mean-zero, signed) once:
                dev = (sin(phase));                        % [-1, +1]
 %                explicit cas form, mean-zero
%                 dev = (cos(phase) + sin(phase)) / sqrt(2); 
                
                texHandles(c) = Screen('MakeTexture', obj.winPtr, dev, 0, [], 1);     % floatprecision=1 (fp16 / signed-int)
            end
        end

        function beforeTrial(obj)
            obj.setRandomSeed();
            obj.frameUpdate = 0;
            if ~obj.bankReady
                obj.bank = obj.buildBank();
                obj.texHandles = obj.buildTextures();
                obj.bankReady = true;
            end
            obj.sampleComponents();
        end

        function reset(obj)
            obj.rng.reset();
            obj.frameUpdate = 0;
            obj.sampleComponents();
        end

        function sampleComponents(obj)
            C = numel(obj.bank)/2; %??? might need to update after spliting

            if obj.uniquePerFrame
                baseIdx = randperm(obj.rng, C, obj.K);
            else
                baseIdx = randi(obj.rng, C, [1 obj.K]);
            end

            % With 50% chance, flip to the −k partner (sets the Hartley phase by +π/2):
            flip_K = rand(obj.rng, 1, obj.K) > 0.5;      % logical
            
            %idx(flip_K) = obj.bank(idx(flip_K)).opp;   % use −k when flip=1
            %flip_K=zeros(1,obj.K)==1;
            Idx=baseIdx;
            Idx(flip_K) = arrayfun(@(i) obj.bank(i).opp, baseIdx(flip_K));
            
            %fx and fy pull from the full bank, flipped are already -fx,-fy
            fx = arrayfun(@(i) obj.bank(i).fx, Idx);
            fy = arrayfun(@(i) obj.bank(i).fy, Idx);

            %50-50 pull for amplitude flip (180 out of phase)
            flip_amp = rand(obj.rng,1,obj.K) > 0.5;                 % 0:+, 1:−
            signA    = 1 - 2*double(flip_amp);                      % +1 or −1

            sf  = hypot(fx, fy);
            ori = rad2deg(mod(atan2(fy, fx), 2*pi));

            %phiSent = -pi/4 * ones(1, obj.K);
            %Phase bookkeeping, its +pi/4 by default but the flipped need
            %-pi/4
%             phaseLUT = [pi/4, -pi/4];
            phaseLUT = pi/4 * ones(1,obj.K);

            %Negative K, with negative amplitude gives you back the
            %quadrature pair, so ~(+k,+pi/4)

            obj.current.idx     = Idx;
            obj.current.fx      = fx;
            obj.current.fy      = fy;
            obj.current.sf      = sf;
            obj.current.ori     = ori;
            obj.current.phase  = phaseLUT;%phaseLUT(1+double(flip_K));        % 0 = +k (−π/4), 1 = −k (−3π/4)
            obj.current.amp  = double(signA)*obj.contrast / sqrt(max(obj.K,1));
%             obj.current.flip_K= double(flip_K);
%             obj.current.flip_amp= double(flip_amp);

            obj.frameUpdate = obj.updateEveryNFrames;
        end

        function beforeFrame(obj)
            Screen('FillRect', obj.winPtr, obj.bgGrey);
            Screen('BlendFunction', obj.winPtr, GL_ONE, GL_ONE);

 %Loop draw         
%             rect = obj.screenRect;
%             for j = 1:obj.K
%                 tj = double(obj.texHandles(obj.current.idx(j)));
% 
%                 % Modulating color option
%                 %                 scale = obj.current.amp(j) * 255;
%                 %                 Screen('DrawTexture', obj.winPtr, tj, [], rect, 0, [], [], [scale scale scale 1]);  % one pass per atom
%                 
%                 scale = obj.current.amp(j);
%                  Screen('DrawTexture', obj.winPtr, tj, [], rect, 0, [], [], [scale scale scale 1]);
%             end

            %This should work, but doesn't
            scalevect = obj.current.amp';
            dst = repmat(obj.screenRect(:), 1, obj.K);  % 4×K
            Screen('DrawTextures', obj.winPtr, double(obj.texHandles(obj.current.idx)), [], dst, 0, [], [], [scalevect scalevect scalevect ones(size(scalevect))]');
            
            %Put blending back on the shelf for the next person to use it
            Screen('BlendFunction', obj.winPtr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        end

        function afterFrame(obj)
            obj.frameUpdate = obj.frameUpdate - 1;
            if obj.frameUpdate <= 0
                obj.sampleComponents();
            end
        end

        function CloseUp(obj)
            if ~isempty(obj.texHandles)
                for k = 1:numel(obj.texHandles)
                    if obj.texHandles(k) > 0
                        Screen('Close', obj.texHandles(k));
                    end
                end
            end
            obj.texHandles = [];
            obj.bankReady = false;

            % Return screen to previous condition
            Screen('ColorRange', obj.winPtr, obj.oldmaximumvalue, obj.oldclampcolors, obj.oldapplyToDoubleInputMakeTexture);
        end

        function I = getImage(obj, rect, binSize)
            if nargin < 2 || isempty(rect),    rect = obj.screenRect; end
            if nargin < 3 || isempty(binSize), binSize = 1; end

            w = RectWidth(obj.screenRect);
            h = RectHeight(obj.screenRect);

            [xPix, yPix] = meshgrid( (1:w) - (w+1)/2, ...
                         (1:h) - (h+1)/2 );
            Xdeg =  xPix / obj.pixPerDeg;
            Ydeg = -yPix / obj.pixPerDeg;

            acc = zeros(h, w, 'double');

            %Flips indicate tiling phase by pi/2,
            %             phi = [-π/4, +π/4]
            %             sgn = [+1,-1]

            %We are making our quad pairs (phi = pi/4) by -k and -amplitude,
            % so we don't want/need to also change the phase
            %phi =(obj.current.phase); leaving in a per component phase for
            %testing

            for j = 1:obj.K
                fx = obj.current.fx(j); fy = obj.current.fy(j);
                %                 s = phaseLUT(obj.current.phase2(j)+1);
                phi =(obj.current.phase(j));
                %acc = acc + sin( 2*pi*(fx.*Xdeg + fy.*Ydeg) + pi/2 );
                acc = acc + sin( 2*pi*(fx.*Xdeg + fy.*Ydeg)+phi)*(obj.current.amp(j));
            end

            Ilin = obj.bgGrey+acc; %(double(127)/255) + acc;
            Ilin = min(max(Ilin, 0), 1);

            L = max(1, round(rect(1) - obj.screenRect(1) + 1));
            T = max(1, round(rect(2) - obj.screenRect(2) + 1));
            R = min(w, round(rect(3) - obj.screenRect(1)));
            B = min(h, round(rect(4) - obj.screenRect(2)));
            Ilin = Ilin(T:B, L:R);

            if binSize > 1
                Ilin = localBoxDownsample(Ilin, binSize);
            end
            I = uint8(round(Ilin * 255));
        end

        function row = currentLogRowNumeric(obj, whenTimestamp)
            if nargin<2, whenTimestamp = NaN; end
            t   = double(whenTimestamp);
            K   = double(obj.K);
            fx  = double(obj.current.fx(:)).';
            fy  = double(obj.current.fy(:)).';
            %ph  = double(obj.current.phase(:)).';
            amp = double(obj.current.amp);
            idx = double(obj.current.idx(:)).';
            row = [t, K, fx, fy, amp, idx]; 
        end
    end
end

function J = localBoxDownsample(A, s)
    [h,w] = size(A);
    hh = floor(h/s)*s; ww = floor(w/s)*s;
    if hh ~= h || ww ~= w, A = A(1:hh, 1:ww); end
    A = reshape(A, s, hh/s, s, ww/s);
    J = squeeze(mean(mean(A, 1), 3));
end


function [sx, sy, out] = pickHartleyStridesFromNs(Wdeg, Hdeg, FmaxX, FmaxY, ns)
% Pick integer strides (sx, sy) for a tight rectangular Hartley sublattice
% such that nx = ny = ns exactly, where
%   nx = 2*floor(Kx_max/sx) + 1,  ny = 2*floor(Ky_max/sy) + 1.
%
% Inputs
%   Wdeg, Hdeg : field of view (deg)
%   FmaxX, FmaxY : rectangular bandlimit (|fx|<=FmaxX, |fy|<=FmaxY) in cyc/deg
%   ns        : desired points per axis (including zero), must be odd, >=3
%
% Outputs
%   sx, sy    : integer strides
%   out       : struct with details

    arguments
        Wdeg (1,1) double {mustBePositive}
        Hdeg (1,1) double {mustBePositive}
        FmaxX (1,1) double {mustBePositive}
        FmaxY (1,1) double {mustBePositive}
        ns (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(ns,3)}
    end

    if mod(ns,2)==0
        error('ns must be odd (includes DC). Example: ns=25 gives a 25x25 grid.');
    end

    % Integer-cycle bounds
    Kx_max = floor(Wdeg * FmaxX);
    Ky_max = floor(Hdeg * FmaxY);

    % Feasibility: maximum ns per axis is 2*K_max+1 (stride=1)
    ns_max_x = 2*Kx_max + 1;
    ns_max_y = 2*Ky_max + 1;
    ns_max   = min(ns_max_x, ns_max_y);
    if ns > ns_max
        error('ns=%d not feasible (max %d for given W/H and FmaxX/Y).', ns, ns_max);
    end

    m = (ns - 1)/2;   % desired floor(K_max/s) on each axis

    % Stride must satisfy: floor(Kx_max/sx) = m  and  floor(Ky_max/sy) = m.
    % That implies open/closed intervals:
    %   K_max/(m+1) < s <= K_max/m
    x_lo = floor(Kx_max / (m+0));   % upper bound (inclusive)
    x_hi = floor((Kx_max) / (m+1)); % lower bound strict, we'll +1 later
    y_lo = floor(Ky_max / (m+0));
    y_hi = floor((Ky_max) / (m+1));

    % Build integer candidate sets respecting (K/(m+1), K/m]
    sx_cand = (max(1,y_hi)+0); %#ok<NASGU> % dummy to keep editor quiet
    sx_cand = ( (floor(Kx_max/(m+1))+1) : x_lo );
    sy_cand = ( (floor(Ky_max/(m+1))+1) : y_lo );

    if isempty(sx_cand) || isempty(sy_cand)
        error('No integer strides satisfy nx=ny=ns. Try smaller ns.');
    end

    % Pick (sx,sy) whose ratio best matches Wdeg/Hdeg (≈ isotropic spacing in cyc/deg)
    rho_des = Wdeg / Hdeg;
    best = struct('sx',NaN,'sy',NaN,'ratioErr',Inf);
    for sx_try = sx_cand
        % sy that gets close in ratio
        sy_ideal = round(sx_try / rho_des);
        for sy_try = unique([sy_ideal-1 sy_ideal sy_ideal+1 sy_cand])  % check a few near-ideal + full set
            if sy_try < min(sy_cand) || sy_try > max(sy_cand), continue; end
            ratioErr = abs( (sx_try/sy_try) - rho_des ) / rho_des;
            if ratioErr < best.ratioErr
                best.sx = sx_try; best.sy = sy_try; best.ratioErr = ratioErr;
            end
        end
    end

    if isnan(best.sx)
        error('Could not match ratio; this should be rare. Try adjusting ns slightly.');
    end

    sx = best.sx; sy = best.sy;

    % Report
    nx = 2*floor(Kx_max/sx) + 1;
    ny = 2*floor(Ky_max/sy) + 1;
    out = struct;
    out.Kx_max = Kx_max; out.Ky_max = Ky_max;
    out.ns = ns; out.nx = nx; out.ny = ny; out.N_total = nx*ny - 1; % minus DC
    out.fx_step = sx / Wdeg; out.fy_step = sy / Hdeg;
    out.ratio_des = rho_des; out.ratio = sx/sy;
end

