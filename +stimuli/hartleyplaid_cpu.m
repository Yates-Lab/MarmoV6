classdef hartleyplaid_cpu
% CPU-only Hartley hartleyplaid generator, no Screen() calls.
% - Centered pixel grid (exact center if w,h are odd).
% - Rectangular |fx|<=FmaxX, |fy|<=FmaxY sublattice, even strides.
% - Canonical half-plane + explicit (-k) partners (phase LUT).
% - Deterministic RNG unless you pass a seed.

    properties
        % geometry / sampling
        screenRect   % [x0 y0 x1 y1], only size matters here
        pixPerDeg double = 60

        % design
        FmaxX_cpd double = 8
        FmaxY_cpd double = 8
        strideKx double = []   % auto-picked if empty via ns=25
        strideKy double = []
        K double = 6
        contrast double = 0.4  % overall RMS target

        % runtime
        bgGrey double = 0.5    % linear [0..1]
        bank                     % struct array with fx,fy,sf,th,ori,opp
        Xdeg; Ydeg               % precomputed grids (double, centered)
        current                  % .idx, .fx, .fy, .phase, .amp
        rng                      % RandStream
    end

    methods
        function obj = hartleyplaid_cpu(varargin)
            % Parse simple name/value pairs
            p = inputParser;
            p.addParameter('screenRect', [0 0 641 481]);
            p.addParameter('pixPerDeg', 60);
            p.addParameter('FmaxX', 8);
            p.addParameter('FmaxY', 8);
            p.addParameter('K', 6);
            p.addParameter('contrast', 0.4);
            p.addParameter('ns', 25);       % desired nx=ny for stride picking
            p.addParameter('seed', 1);      % deterministic by default
            p.parse(varargin{:});

            obj.screenRect = p.Results.screenRect;
            obj.pixPerDeg  = p.Results.pixPerDeg;
            obj.FmaxX_cpd  = p.Results.FmaxX;
            obj.FmaxY_cpd  = p.Results.FmaxY;
            obj.K          = p.Results.K;
            obj.contrast   = p.Results.contrast;
            obj.rng        = RandStream('mt19937ar','Seed', p.Results.seed);

            % Precompute grids (center at (w+1)/2, (h+1)/2)
            w = RectWidth(obj.screenRect);
            h = RectHeight(obj.screenRect);
            [xPix, yPix] = meshgrid( (1:w) - (w+1)/2, (1:h) - (h+1)/2 );
            obj.Xdeg =  xPix / obj.pixPerDeg;
            obj.Ydeg = -yPix / obj.pixPerDeg;

            % Pick strides to get nx=ny=ns exactly
            Wdeg = w / obj.pixPerDeg;  Hdeg = h / obj.pixPerDeg;
            [sx, sy] = hartleyplaid_cpu.pickHartleyStridesFromNs(Wdeg, Hdeg, ...
                         obj.FmaxX_cpd, obj.FmaxY_cpd, p.Results.ns);
            obj.strideKx = sx; obj.strideKy = sy;

            % Build ±k bank with partner indices
            obj.bank = obj.buildBank();

            % Prime a first frame
            obj = obj.sampleComponents();
        end

        function bank = buildBank(obj)
            w = RectWidth(obj.screenRect);
            h = RectHeight(obj.screenRect);
            Wdeg = w / obj.pixPerDeg;
            Hdeg = h / obj.pixPerDeg;

            Kx_max = floor(Wdeg * obj.FmaxX_cpd);
            Ky_max = floor(Hdeg * obj.FmaxY_cpd);

            kx_vals = -Kx_max:obj.strideKx:Kx_max;
            ky_vals = -Ky_max:obj.strideKy:Ky_max;

            [KX, KY] = ndgrid(kx_vals, ky_vals);
            KX = KX(:); KY = KY(:);

            % drop DC only
            keep = ~(KX==0 & KY==0);
            KX = KX(keep); KY = KY(keep);

            % canonical half-plane, then append negatives
            keepHalf = (KX > 0) | (KX==0 & KY > 0);
            KXh = KX(keepHalf); KYh = KY(keepHalf);
            KXp = [ KXh ; -KXh ];
            KYp = [ KYh ; -KYh ];

            fx = KXp / Wdeg;  fy = KYp / Hdeg;
            sf = hypot(fx, fy);
            th = atan2(fy, fx);
            nH = numel(KXh);
            opp = [(nH+1):(2*nH), 1:nH]';  % +k <-> -k

            bank = struct('fx', num2cell(fx), ...
                          'fy', num2cell(fy), ...
                          'sf', num2cell(sf), ...
                          'th', num2cell(th), ...
                          'ori', num2cell(rad2deg(mod(th, 2*pi))), ...
                          'opp', num2cell(opp));
        end

        function obj = sampleComponents(obj)
            % choose from +half-plane only
            C = numel(obj.bank)/2;
            baseIdx = randperm(obj.rng, C, obj.K);

            % 50% chance flip to -k partner => toggles quadrature sign (±π/4 phase)
            flipK = rand(obj.rng, 1, obj.K) > 0.5;
            Idx = baseIdx;
            Idx(flipK) = arrayfun(@(i) obj.bank(i).opp, baseIdx(flipK));

            % optional amplitude sign flip (+/-) – enable if you want the π shift too
            flipA = rand(obj.rng, 1, obj.K) > 0.5;
            signA = 1 - 2*double(flipA);  % +1 or -1

%             phaseLUT = [-pi/4, pi/4];  
            phaseLUT = [pi/4, -pi/4]; % indices 1(+k),2(-k)
            phase    = phaseLUT(1+double(flipK));

            amp_per = (obj.contrast ./ sqrt(max(obj.K,1))) .* signA;

            fx = arrayfun(@(i) obj.bank(i).fx, Idx);
            fy = arrayfun(@(i) obj.bank(i).fy, Idx);

            obj.current.idx   = Idx;
            obj.current.fx    = fx;
            obj.current.fy    = fy;
            obj.current.phase = phase;
            obj.current.amp   = amp_per;
        end

        function [Iu8, Ilin] = renderFrame(obj)
            % Sum K sines with their phases and amplitudes; return uint8 and linear
            acc = zeros(size(obj.Xdeg), 'double');
            for j = 1:obj.K
                acc = acc + obj.current.amp(j) .* ...
                    sin( 2*pi*( obj.current.fx(j).*obj.Xdeg + obj.current.fy(j).*obj.Ydeg ) ...
                         + obj.current.phase(j) );
                % Cas form, equivalent
%                 acc = acc + obj.current.amp(j) * ...
%                       (cos(2*pi*(fx*Xdeg + fy*Ydeg)) + sin(2*pi*(fx*Xdeg + fy*Ydeg))) / sqrt(2);

            end
            Ilin = obj.bgGrey + acc;                 % linear [may exceed]
            Ilin = min(max(Ilin, 0), 1);             % clip to [0..1] for viewing
            Iu8  = uint8(round(Ilin * 255));
        end
    end

    methods(Static)
        function [sx, sy, out] = pickHartleyStridesFromNs(Wdeg,Hdeg,FmaxX,FmaxY,ns)
            arguments
                Wdeg (1,1) double {mustBePositive}
                Hdeg (1,1) double {mustBePositive}
                FmaxX (1,1) double {mustBePositive}
                FmaxY (1,1) double {mustBePositive}
                ns (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(ns,3)}
            end
            if mod(ns,2)==0
                error('ns must be odd (includes DC).');
            end
            Kx_max = floor(Wdeg * FmaxX);
            Ky_max = floor(Hdeg * FmaxY);
            ns_max = min(2*Kx_max+1, 2*Ky_max+1);
            if ns > ns_max, error('ns=%d not feasible (max %d).', ns, ns_max); end
            m = (ns - 1)/2;
            x_lo = floor(Kx_max / m);
            x_hi = floor(Kx_max / (m+1));
            y_lo = floor(Ky_max / m);
            y_hi = floor(Ky_max / (m+1));
            sx_cand = (x_hi+1):x_lo;
            sy_cand = (y_hi+1):y_lo;
            if isempty(sx_cand) || isempty(sy_cand)
                error('No integer strides satisfy nx=ny=ns.');
            end
            rho_des = Wdeg / Hdeg;
            best = struct('sx',NaN,'sy',NaN,'ratioErr',Inf);
            for sx_try = sx_cand
                sy_ideal = round(sx_try / rho_des);
                for sy_try = unique([sy_ideal-1 sy_ideal sy_ideal+1 sy_cand])
                    if sy_try < min(sy_cand) || sy_try > max(sy_cand), continue; end
                    ratioErr = abs( (sx_try/sy_try) - rho_des ) / rho_des;
                    if ratioErr < best.ratioErr
                        best.sx = sx_try; best.sy = sy_try; best.ratioErr = ratioErr;
                    end
                end
            end
            sx = best.sx; sy = best.sy;
            if isnan(sx), error('Could not match ratio; adjust ns.'); end
            if nargout>2
                nx = 2*floor(Kx_max/sx) + 1;
                ny = 2*floor(Ky_max/sy) + 1;
                out = struct('nx',nx,'ny',ny,'fx_step',sx/Wdeg,'fy_step',sy/Hdeg);
            end
        end

        function tbl = exportHartleyFrame(obj, frame)
            K = obj.K;
            Wdeg = RectWidth(obj.screenRect)/obj.pixPerDeg;
            Hdeg = RectHeight(obj.screenRect)/obj.pixPerDeg;

            fx = obj.current.fx(:);
            fy = obj.current.fy(:);
            kx = round(fx * Wdeg);
            ky = round(fy * Hdeg);
            s  = sign(obj.current.amp(:));
            amp = abs(obj.current.amp(:));

            tbl = table(repmat(frame,K,1), kx, ky, s, amp, ...
                'VariableNames', {'frame','kx','ky','sign','amp'});
        end
    end
end
