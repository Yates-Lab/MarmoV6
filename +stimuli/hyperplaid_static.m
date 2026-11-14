classdef hyperplaid_static < stimuli.stimulus
% Full-field static hyperplaid: sum of K gratings per frame (no drift).
% Uses PTB's procedural sine shader. Designed for Hartley-first workflows.
%
% NoiseHistory row layout (numeric):
%   [ t, K, fx(1:K), fy(1:K), phiSent(1:K), amp, idx(1:K) ]
% where:
%   t         : flip timestamp (VBL or your photodiode-aligned time)
%   K         : number of components that frame (scalar, usually obj.K)
%   fx, fy    : cycles/deg per component (post-sampling)
%   phiSent   : phase (radians) actually sent to the shader for each component
%   amp       : per-component amplitude (contrast/sqrt(K)), scalar per frame
%   idx       : indices into the prebuilt lattice bank (for Hartley mode)
%
% Analysis tip: build complex features with gaze correction per frame
%   phi_ret = phiSent + 2*pi*(fx*dx + fy*dy);
%   z       = amp .* exp(1i * phi_ret);

    properties
        % --- display ---
        winPtr
        screenRect
        pixPerDeg
        bgGrey = 127;                  % mean luminance (0..255)

        % --- bank / design ---
        orientations_deg double        % used in cos-sin mode (size O)
        spatialFrequencies_cpd double  % used in cos-sin mode (size S)
        K double = 6                   % components per frame
        M double = 8                   % phase alphabet size (cos-sin mode)
        phaseAlphabet double           % (1×M) radians
        contrast double = 0.4          % RMS target per frame (scaled internally)

        % --- timing ---
        frameRate double
        updateEveryNFrames double      % e.g., ceil(frameRate / 5) for ~5 Hz holds

        % --- geometry ---
        position double = []           % center [x y] in pixels (unused for full-field)
        diameter double = inf          % inf = full field (aperture only used in getImage)

        % --- state ---
        %rng                             % RandStream
        frameUpdate double = 0
        tex                             % procedural sine grating handle
        current                         % struct: idx, fx, fy, sf, ori, phi, phiSent, amp

        % --- probe mode (optional) ---
        probeMode logical = false
        probePairs double = []          % [i j] indices into carrier list (linearized O×S)
        probeDeltaPhases double = []    % vector of Δφ values (radians), length M by default
        probeCursor double = 1

        % --- basis control ---
        basisMode char = 'hartley'      % 'hartley' | 'cos-sin'
        useHartleyLattice logical = true
        hartleyKmax double = []         % integer-cycle radius (auto if empty)
        uniquePerFrame logical = true   % sample without replacement when true
        bank                            % struct array from buildBank()
    end

    methods
        function obj = hyperplaid_static(winPtr, varargin)
            obj = obj@stimuli.stimulus();
            obj.winPtr = winPtr;

            ip = inputParser();
            % display
            ip.addParameter('screenRect', []);
            ip.addParameter('pixPerDeg', 60);
            ip.addParameter('frameRate', 60);
            % bank choices for cos-sin mode
            ip.addParameter('orientations', 0:30:150);
            ip.addParameter('spatialFrequencies', 3*2.^linspace(-1,1,5)); % cpd
            % core stimulus
            ip.addParameter('K', 6);
            ip.addParameter('M', 8);
            ip.addParameter('contrast', 0.4);
            ip.addParameter('updateEveryNFrames', []);
            % probes
            ip.addParameter('probeMode', false);
            ip.addParameter('probePairs', []);
            ip.addParameter('probeDeltaPhases', []);
            % basis / lattice
            ip.addParameter('basisMode', 'hartley');
            ip.addParameter('useHartleyLattice', true);
            ip.addParameter('hartleyKmax', []);
            ip.addParameter('uniquePerFrame', true);

            ip.parse(varargin{:});

            obj.screenRect             = ip.Results.screenRect;
            obj.pixPerDeg              = ip.Results.pixPerDeg;
            obj.frameRate              = ip.Results.frameRate;
            obj.orientations_deg       = ip.Results.orientations;
            obj.spatialFrequencies_cpd = ip.Results.spatialFrequencies;
            obj.K                      = ip.Results.K;
            obj.M                      = ip.Results.M;
            obj.contrast               = ip.Results.contrast;
            obj.probeMode              = ip.Results.probeMode;
            obj.probePairs             = ip.Results.probePairs;
            obj.probeDeltaPhases       = ip.Results.probeDeltaPhases;
            obj.basisMode              = ip.Results.basisMode;
            obj.useHartleyLattice      = ip.Results.useHartleyLattice;
            obj.hartleyKmax            = ip.Results.hartleyKmax;
            obj.uniquePerFrame         = ip.Results.uniquePerFrame;

            if isempty(ip.Results.updateEveryNFrames)
                obj.updateEveryNFrames = ceil(obj.frameRate / 5); % ~5 Hz holds
            else
                obj.updateEveryNFrames = ip.Results.updateEveryNFrames;
            end

            obj.phaseAlphabet = (0:obj.M-1) * (2*pi/obj.M);
            if isempty(obj.probeDeltaPhases)
                obj.probeDeltaPhases = obj.phaseAlphabet;
            end

            % RNG, inherits from stimulus class
            %obj.rng = RandStream('mt19937ar','Seed',sum(100*clock));

            % Build lattice bank if requested
            if obj.useHartleyLattice
                obj.bank = obj.buildBank();
            else
                obj.bank = [];
            end

            % PTB procedural sine with zero base color (we draw bg once)
            w = RectWidth(obj.screenRect);
            h = RectHeight(obj.screenRect);
            obj.tex = CreateProceduralSineGrating(obj.winPtr, w, h, [0 0 0 0]);
        end

        function bank = buildBank(obj)
            % Build lattice of integer cycles across the full field.
            Wdeg = RectWidth(obj.screenRect)/obj.pixPerDeg;
            Hdeg = RectHeight(obj.screenRect)/obj.pixPerDeg;

            if isempty(obj.hartleyKmax)
                nxmax = floor(Wdeg * max(obj.spatialFrequencies_cpd));
                nymax = floor(Hdeg * max(obj.spatialFrequencies_cpd));
            else
                nxmax = obj.hartleyKmax;
                nymax = obj.hartleyKmax;
            end
            [NX, NY] = ndgrid(-nxmax:nxmax, -nymax:nymax);
            keep = ~(NX==0 & NY==0);    % drop DC (optional)
            NX = NX(keep); NY = NY(keep);

            fx = NX / Wdeg;             % cycles/deg
            fy = NY / Hdeg;
            sf = hypot(fx, fy);
            th = atan2(fy, fx);

            % keep lattice points within requested SF band
            sfInBand = sf >= min(obj.spatialFrequencies_cpd) & sf <= max(obj.spatialFrequencies_cpd);
            fx = fx(sfInBand); fy = fy(sfInBand); sf = sf(sfInBand); th = th(sfInBand);

            % half-plane representative to avoid ±k redundancy
            keepHalf = (fx>0) | (fx==0 & fy>0);
            fx = fx(keepHalf); fy = fy(keepHalf); sf = sf(keepHalf); th = th(keepHalf);

            bank = struct('fx', num2cell(fx), 'fy', num2cell(fy), ...
                          'sf', num2cell(sf), 'th', num2cell(th), ...
                          'ori', num2cell(rad2deg(mod(th, 2*pi))));
        end

        function [idx, fx, fy, phi] = sampleHartley(obj)
            % Draw K lattice atoms (half-plane). Hartley phase is -π/4; random sign via +π.
            C = numel(obj.bank);
            if obj.uniquePerFrame
                idx = randperm(obj.rng, C, obj.K);
            else
                idx = randi(obj.rng, C, [1 obj.K]);
            end
            fx  = arrayfun(@(i) obj.bank(i).fx, idx);
            fy  = arrayfun(@(i) obj.bank(i).fy, idx);

            phi = -pi/4 * ones(1, obj.K);                % Hartley cas phase
            flips = randi(obj.rng, 2, [1 obj.K])*2 - 3;  % {-1,+1}
            phi(flips<0) = phi(flips<0) + pi;            % random sign folded into phase
        end

        function beforeTrial(obj)
            obj.setRandomSeed();
            obj.frameUpdate = 0;
            obj.sampleComponents(); % prime first frame
        end

        function reset(obj)
            obj.rng.reset();
            obj.frameUpdate = 0;
            obj.sampleComponents();
        end

        function sampleComponents(obj)
            if strcmp(obj.basisMode,'hartley')
                [idx, fx, fy, phi] = obj.sampleHartley();

                % Orientation/SF for drawing/logging
                sf  = hypot(fx, fy);
                ori = rad2deg(mod(atan2(fy, fx), 2*pi));

                % Optional probe: enforce Δφ on first pair (temporary non-Hartley)
                if obj.probeMode && ~isempty(obj.probePairs)
                    dphi = obj.probeDeltaPhases( mod(obj.probeCursor-1, numel(obj.probeDeltaPhases)) + 1 );
                    obj.probeCursor = obj.probeCursor + 1;
                    % choose a random phase on the alphabet and enforce Δφ
                    phi(1) = obj.phaseAlphabet(randi(obj.rng, obj.M));
                    phi(2) = phi(1) + dphi;
                end

                obj.current.idx     = idx;
                obj.current.fx      = fx;
                obj.current.fy      = fy;
                obj.current.sf      = sf;
                obj.current.ori     = ori;
                obj.current.phi     = phi;                         % design phase (for your reference)
                obj.current.phiSent = phi;                         % actually sent to shader
                obj.current.amp     = obj.contrast / sqrt(max(obj.K,1));

            else
                % cos-sin mode on a user grid (O×S). Also compute fx/fy for logging.
                O = numel(obj.orientations_deg);
                S = numel(obj.spatialFrequencies_cpd);
                C = O*S;

                idx = randperm(obj.rng, C, obj.K);
                [oi, si] = ind2sub([O S], idx);
                ori = obj.orientations_deg(oi);
                sf  = obj.spatialFrequencies_cpd(si);

                th  = deg2rad(ori);
                fx  = sf .* cos(th);
                fy  = sf .* sin(th);

                phi = obj.phaseAlphabet(randi(obj.rng, obj.M, [1 obj.K]));
                sgn = randi(obj.rng, 2, [1 obj.K])*2 - 3;          % {-1,+1}
                phiSent = phi;
                phiSent(sgn<0) = phiSent(sgn<0) + pi;              % fold sign into phase

                % Optional Δφ probe on first pair
                if obj.probeMode && ~isempty(obj.probePairs)
                    p    = obj.probePairs( mod(obj.probeCursor-1, size(obj.probePairs,1)) + 1, : );
                    dphi = obj.probeDeltaPhases( mod(obj.probeCursor-1, numel(obj.probeDeltaPhases)) + 1 );
                    obj.probeCursor = obj.probeCursor + 1;

                    % ensure both members of the pair are in set; if not, replace first two
                    idx(1:2) = p(:)';
                    [oi, si] = ind2sub([O S], idx);
                    ori = obj.orientations_deg(oi);
                    sf  = obj.spatialFrequencies_cpd(si);
                    th  = deg2rad(ori);
                    fx  = sf .* cos(th);
                    fy  = sf .* sin(th);

                    phi       = obj.phaseAlphabet(randi(obj.rng, obj.M, [1 obj.K]));
                    phiSent   = phi;
                    phiSent(1) = obj.phaseAlphabet(randi(obj.rng, obj.M));
                    phiSent(2) = phiSent(1) + dphi;
                end

                obj.current.idx     = idx;
                obj.current.fx      = fx;
                obj.current.fy      = fy;
                obj.current.sf      = sf;
                obj.current.ori     = ori;
                obj.current.phi     = phi;
                obj.current.phiSent = phiSent;
                obj.current.amp     = obj.contrast / sqrt(max(obj.K,1));
            end

            obj.frameUpdate = obj.updateEveryNFrames;
        end

        function beforeFrame(obj)
            % Draw background ONCE
            Screen('FillRect', obj.winPtr, obj.bgGrey);

            % Additive blend for components
            Screen('BlendFunction', obj.winPtr, GL_ONE, GL_ONE);

            rect = obj.screenRect;
            for j = 1:obj.K
                angDeg = obj.current.ori(j);
                sf_cpp = obj.current.sf(j) / obj.pixPerDeg;   % cycles/pixel
                phi    = obj.current.phiSent(j);
                aux    = [phi, sf_cpp, obj.current.amp, 1];   % [phase(rad), freq(cpp), contrast, aspect]
                %kPsychDontDoRotation off
                Screen('DrawTexture', obj.winPtr, obj.tex, [], rect, angDeg, [], [], [], [], [], aux);
            end

            % Restore normal alpha blending
            Screen('BlendFunction', obj.winPtr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        end

        function afterFrame(obj)
            % Count down; when it hits 0, sample next set
            obj.frameUpdate = obj.frameUpdate - 1;
            if obj.frameUpdate <= 0
                obj.sampleComponents();
            end
        end

        function updateTextures(obj, varargin) %#ok<INUSD>
            % procedural sine has nothing to precompute
        end

        function CloseUp(obj)
            if ~isempty(obj.tex)
                Screen('Close', obj.tex); obj.tex = [];
            end
        end

        function I = getImage(obj, rect, binSize) %#ok<INUSL>
        % CPU renderer for the *current* components; matches shader if the
        % window is linearized and background is drawn once per frame.
        %
        % Inputs:
        %   rect     [l t r b] crop in window pixels (default: full screenRect)
        %   binSize  integer downsample factor via box-averaging (default: 1)
            if nargin < 2 || isempty(rect),    rect = obj.screenRect; end
            if nargin < 3 || isempty(binSize), binSize = 1; end

            % sizes & center
            w = RectWidth(obj.screenRect);
            h = RectHeight(obj.screenRect);
            cx = (obj.screenRect(1) + obj.screenRect(3)) / 2;
            cy = (obj.screenRect(2) + obj.screenRect(4)) / 2;
            if ~isempty(obj.position)
                cx = obj.position(1);
                cy = obj.position(2);
            end

            % pixel grid (y up in degrees)
            [xPix, yPix] = meshgrid( (1:w) + obj.screenRect(1) - cx, ...
                                     (1:h)' + obj.screenRect(2) - cy );
            Xdeg =  xPix / obj.pixPerDeg;
            Ydeg = -yPix / obj.pixPerDeg;

            % optional aperture (analysis uses full-field; renderer keeps parity)
            if isfinite(obj.diameter)
                rDeg  = (obj.diameter / obj.pixPerDeg) / 2;   % radius in deg
                maskA = (Xdeg.^2 + Ydeg.^2) <= rDeg^2;
            else
                maskA = true(h, w);
            end

            % sum K components (use fx/fy if available; fallback to ori/sf)
            acc = zeros(h, w, 'double');
            for j = 1:obj.K
                if isfield(obj.current,'fx')
                    fx = obj.current.fx(j); fy = obj.current.fy(j);
                else
                    th = deg2rad(obj.current.ori(j)); sf = obj.current.sf(j);
                    fx = sf*cos(th); fy = sf*sin(th);
                end
                phi   = obj.current.phiSent(j);
                phase = 2*pi*(fx.*Xdeg + fy.*Ydeg) + phi;
                acc   = acc + sin(phase);                      % PTB shader draws sine
            end

            % amplitude + background (once)
            Ilin = (double(obj.bgGrey)/255) + obj.current.amp * acc;
            Ilin(~maskA) = double(obj.bgGrey)/255;
            Ilin = min(max(Ilin, 0), 1);

            % crop
            L = max(1, round(rect(1) - obj.screenRect(1) + 1));
            T = max(1, round(rect(2) - obj.screenRect(2) + 1));
            R = min(w, round(rect(3) - obj.screenRect(1)));
            B = min(h, round(rect(4) - obj.screenRect(2)));
            Ilin = Ilin(T:B, L:R);

            % optional downsample
            if binSize > 1
                Ilin = localBoxDownsample(Ilin, binSize);
            end

            I = uint8(round(Ilin * 255));
        end

        function row = currentLogRowNumeric(obj, whenTimestamp)
        % Return a single numeric row for NoiseHistory:
        %   [ t, K, fx(1:K), fy(1:K), phiSent(1:K), amp, idx(1:K) ]
            if nargin<2, whenTimestamp = NaN; end
            t   = double(whenTimestamp);
            K   = double(obj.K);
            fx  = double(obj.current.fx(:)).';
            fy  = double(obj.current.fy(:)).';
            ph  = double(obj.current.phiSent(:)).';
            amp = double(obj.current.amp);
            if isfield(obj.current,'idx')
                idx = double(obj.current.idx(:)).';
            else
                idx = double(zeros(1, obj.K)); % 0 if not using lattice bank
            end
            row = [t, K, fx, fy, ph, amp, idx];
        end
    end
end

function J = localBoxDownsample(A, s)
% Box-average downsample by integer factor s (no toolboxes).
    [h,w] = size(A);
    hh = floor(h/s)*s; ww = floor(w/s)*s;
    if hh ~= h || ww ~= w
        A = A(1:hh, 1:ww);
    end
    A = reshape(A, s, hh/s, s, ww/s);
    J = squeeze(mean(mean(A, 1), 3));
end
