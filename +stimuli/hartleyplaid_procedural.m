classdef hartleyplaid_procedural < stimuli.stimulus
% Full-field static Hartley Hyperplaid (K gratings/frame, no drift).
% Procedural (shader-backed) version using explicit OpenGL calls only.
%
% Drop-in replacement for hartleyplaid_static:
% - Same constructor signature and public methods.
% - Same 'current' struct fields and logging row format.
% - Photometry: we draw mean-zero deviations additively on top of bgGrey,
%   matching the static path where precomputed textures were summed.

    properties
        % --- display ---
        winPtr
        screenRect
        pixPerDeg
        bgGrey = 0.5
        linearize = true

        % --- design ---
        maxSF double = 8
        spatialFrequencies_cpd double = 3 * 2.^linspace(-1,1,5)
        K double = 6
        contrast double = 0.4

        ns double = 6
        equalStride logical = false


        % --- timing ---
        frameRate double = 60
        updateEveryNFrames double = []

        % --- geometry ---
        position double = []
        diameter double = inf

        % --- Hartley lattice parameters ---
        useHartleyLattice logical = true
        hartleyKmax double = []
        FmaxX_cpd double = 8
        FmaxY_cpd double = 8
        strideKx double = 32
        strideKy double = 18

        uniquePerFrame logical = true
        bank
        texHandles
        bankReady logical = false

        % --- runtime state ---
        frameUpdate double = 0
        current

        % --- GL / Shader ---
        gl_inited logical = false
        shader
        GL_BLEND            = hex2dec('0BE2')
        GL_ONE              = 1
        GL_SRC_ALPHA        = hex2dec('0302')
        GL_ONE_MINUS_SRC_ALPHA = hex2dec('0303')
        GL_QUADS            = hex2dec('0007')
        offwin = []
        offRect = []

        % --- PTB color-range restore ---
        oldmaximumvalue
        oldclampcolors
        oldapplyToDoubleInputMakeTexture
    end

    methods
        function obj = hartleyplaid_procedural(winPtr, varargin)
            obj = obj@stimuli.stimulus();
            obj.winPtr = winPtr;

            % Assume InitializeMatlabOpenGL was already called before window open
            [obj.oldmaximumvalue, obj.oldclampcolors, obj.oldapplyToDoubleInputMakeTexture] = ...
                Screen('ColorRange', winPtr, 1, 0);
            
            Screen('FillRect', obj.winPtr, 0.5);
            Screen('Flip', winPtr, 1, 0);

            % ---- Parse args ----
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
            ip.addParameter('maxSF', obj.maxSF);
            ip.addParameter('uniquePerFrame', true);
            ip.addParameter('bgGrey', obj.bgGrey);
            ip.addParameter('linearize', true);
            ip.addParameter('ns', obj.ns);
            ip.addParameter('equalStride', obj.equalStride);
            ip.parse(varargin{:});

            obj.screenRect             = ip.Results.screenRect;
            obj.pixPerDeg              = ip.Results.pixPerDeg;
            obj.frameRate              = ip.Results.frameRate;
            obj.spatialFrequencies_cpd = ip.Results.spatialFrequencies;
            obj.K                      = ip.Results.K;
            obj.contrast               = ip.Results.contrast;
            obj.useHartleyLattice      = ip.Results.useHartleyLattice;
            obj.hartleyKmax            = ip.Results.hartleyKmax;
            obj.FmaxX_cpd              = ip.Results.maxSF;
            obj.FmaxY_cpd              = ip.Results.maxSF;
            obj.uniquePerFrame         = ip.Results.uniquePerFrame;
            obj.bgGrey                 = 0.5;
            obj.linearize              = ip.Results.linearize;
            obj.ns                     = ip.Results.ns;
            obj.equalStride            = ip.Results.equalStride;

            if isempty(ip.Results.updateEveryNFrames)
                obj.updateEveryNFrames = ceil(obj.frameRate/60);
            else
                obj.updateEveryNFrames = ip.Results.updateEveryNFrames;
            end

            obj.offRect = obj.screenRect;
            % obj.offwin  = Screen('OpenOffscreenWindow', obj.winPtr, obj.bgGrey, obj.offRect,32);
%            Screen('ColorRange', obj.offwin, 1, 0);  % <--- Disable clamping here too

            % ---- Choose strides ----
            Wdeg = (obj.screenRect(3)-obj.screenRect(1)) / obj.pixPerDeg;
            Hdeg = (obj.screenRect(4)-obj.screenRect(2)) / obj.pixPerDeg;
            [sx, sy, info] = pickHartleyStridesFromNs(Wdeg, Hdeg, obj.FmaxX_cpd, ...
                obj.FmaxY_cpd, obj.ns, 'equalStride', obj.equalStride);
            obj.strideKx = sx; obj.strideKy = sy;
            fprintf('Strides picked: sx=%d, sy=%d, nx=%d, ny=%d, N=%d, fx_step=%.3f, fy_step=%.3f\n', ...
                    sx, sy, info.nx, info.ny, info.N_total, info.fx_step, info.fy_step);

            obj.bank = obj.buildBank();
            obj.initGLAndShader();
            obj.bankReady = true;
        end

        function bank = buildBank(obj)
            Wdeg = RectWidth(obj.screenRect)/obj.pixPerDeg;
            Hdeg = RectHeight(obj.screenRect)/obj.pixPerDeg;

            Kx_max = floor(Wdeg * obj.FmaxX_cpd);
            Ky_max = floor(Hdeg * obj.FmaxY_cpd);
            % kx_vals = -Kx_max:obj.strideKx:Kx_max;
            kx_vals_=obj.strideKx:obj.strideKx:Kx_max;
            kx_vals=[-kx_vals_(end:-1:1) 0 kx_vals_];
            % ky_vals = -Ky_max:obj.strideKy:Ky_max;
            ky_vals_=obj.strideKy:obj.strideKy:Ky_max;
            ky_vals=[-ky_vals_(end:-1:1) 0 ky_vals_];
            [KX, KY] = ndgrid(kx_vals, ky_vals);
            KX = KX(:); KY = KY(:);
            keep = ~(KX==0 & KY==0);
            KX = KX(keep); KY = KY(keep);
            keepHalf = (KX > 0) | (KX==0 & KY > 0);
            KXh = KX(keepHalf); KYh = KY(keepHalf);
            KXp = [KXh ; -KXh];
            KYp = [KYh ; -KYh];
            fx = KXp / Wdeg; fy = KYp / Hdeg;
            sf = hypot(fx, fy); th = atan2(fy, fx);
            nH = numel(KXh); opp = [(nH+1):(2*nH), 1:nH]';
            bank = struct('fx', num2cell(fx), ...
                          'fy', num2cell(fy), ...
                          'kx', num2cell(KXp), ...
                          'ky', num2cell(KYp), ...
                          'sf', num2cell(sf), ...
                          'th', num2cell(th), ...
                          'ori', num2cell(rad2deg(mod(th, 2*pi))), ...
                          'opp', num2cell(opp));
        end

        function initGLAndShader(obj)
            if ~obj.gl_inited
                PsychDefaultSetup(2);
                obj.gl_inited = true;
            end
            [scriptPath, ~, ~] = fileparts(mfilename('fullpath'));
            if isempty(scriptPath), scriptPath = pwd; end
            obj.shader.vertFile = fullfile(scriptPath, 'hartleyplaid_procedural.vert');
            obj.shader.fragFile = fullfile(scriptPath, 'hartleyplaid_procedural.frag');

            % --- Vertex shader: fixed-function compatible ---
            fv = fopen(obj.shader.vertFile, 'w');
            fprintf(fv, [
                'varying vec2 uv;\n' ...
                'void main(void) {\n' ...
                '  vec2 pos = gl_Vertex.xy;\n' ...
                '  uv = pos * 0.5;  // now uv ∈ [−0.5, +0.5];\n' ... %uv = 0.5 * (pos + 1.0);\n' ...
                '  gl_Position = vec4(pos, 0.0, 1.0);\n' ...
                '}\n']);
            fclose(fv);

            % --- Fragment shader: mean-zero deviation ---
            ff = fopen(obj.shader.fragFile, 'w');
            fprintf(ff, [
                'uniform float kx;\n' ...
                'uniform float ky;\n' ...
                'uniform float signVal;\n' ...
                'uniform float amplitude;\n' ...
                'varying vec2 uv;\n' ...
                'const float PI = 3.1415926535;\n' ...
                'void main(void) {\n' ...
                '  float phase = 2.0 * PI * (kx * uv.x + ky * uv.y);\n' ...
                '  float cas = (cos(phase) + sin(phase)) * 0.7071067811865476;\n' ...
                '  float dev = amplitude * signVal * cas;\n' ...
                '  gl_FragColor = vec4(dev, dev, dev, 1.0);\n' ...
                '}\n']);
            fclose(ff);

            obj.shader.program = LoadGLSLProgramFromFiles({obj.shader.vertFile, obj.shader.fragFile});
            if obj.shader.program <= 0
                error('Failed to compile/link hartleyplaid shaders.');
            end
            glUseProgram(obj.shader.program);
            obj.shader.loc_kx   = glGetUniformLocation(obj.shader.program, 'kx');
            obj.shader.loc_ky   = glGetUniformLocation(obj.shader.program, 'ky');
            obj.shader.loc_sign = glGetUniformLocation(obj.shader.program, 'signVal');
            obj.shader.loc_amp  = glGetUniformLocation(obj.shader.program, 'amplitude');
            glUseProgram(0);
        end

        function beforeTrial(obj)
            obj.setRandomSeed();
            obj.frameUpdate = 0;
            if ~obj.bankReady
                obj.bank = obj.buildBank();
                obj.initGLAndShader();
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
            C = numel(obj.bank)/2;
            if obj.uniquePerFrame
                baseIdx = randperm(obj.rng, C, obj.K);
            else
                baseIdx = randi(obj.rng, C, [1 obj.K]);
            end
            flip_K = rand(obj.rng, 1, obj.K) > 0.5;
            Idx = baseIdx;
            Idx(flip_K) = arrayfun(@(i) obj.bank(i).opp, baseIdx(flip_K));
            fx = arrayfun(@(i) obj.bank(i).fx, Idx);
            fy = arrayfun(@(i) obj.bank(i).fy, Idx);
            kx = arrayfun(@(i) obj.bank(i).kx, Idx);
            ky = arrayfun(@(i) obj.bank(i).ky, Idx);
            flip_amp = rand(obj.rng,1,obj.K) > 0.5;
            signA    = 1 - 2*double(flip_amp);
            sf  = hypot(fx, fy);
            ori = rad2deg(mod(atan2(fy, fx), 2*pi));
            obj.current.idx   = Idx;
            obj.current.fx    = fx;
            obj.current.fy    = fy;
            obj.current.kx    = kx;
            obj.current.ky    = ky;
            obj.current.sf    = sf;
            obj.current.ori   = ori;
            obj.current.phase = pi/4 * ones(1, obj.K);
            obj.current.amp   = double(signA) * obj.contrast / sqrt(max(obj.K,1));
            obj.frameUpdate = obj.updateEveryNFrames;
        end

        function beforeFrame(obj)
            % Draw directly into onscreen window (no offscreen FBO)
            % Equivalent additive accumulation on unclamped main framebuffer.

            % --- 1. Enter PTB's OpenGL context ---
            Screen('BeginOpenGL', obj.winPtr);

            % --- 2. Prepare viewport and clear to mid-gray ---
            glViewport(0, 0, RectWidth(obj.screenRect), RectHeight(obj.screenRect));
            glClearColor(obj.bgGrey, obj.bgGrey, obj.bgGrey, 1.0);
            glClear(hex2dec('00004000'));  % GL_COLOR_BUFFER_BIT

            % --- 3. Set additive blending for mean-zero deviations ---
            glEnable(obj.GL_BLEND);
            glBlendEquation(hex2dec('8006'));  % GL_FUNC_ADD
            glBlendFunc(obj.GL_ONE, obj.GL_ONE);  % additive: out = src + dst

            % --- 4. Use the compiled shader ---
            glUseProgram(obj.shader.program);

            for j = 1:obj.K
                ampMag = abs(obj.current.amp(j));
                sgn    = sign(obj.current.amp(j));
                if sgn == 0, sgn = 1; end  % safety

                % Pass uniforms
                glUniform1f(obj.shader.loc_kx,   obj.current.kx(j));
                glUniform1f(obj.shader.loc_ky,   obj.current.ky(j));
                glUniform1f(obj.shader.loc_sign, sgn);
                glUniform1f(obj.shader.loc_amp,  ampMag);

                % Full-screen quad in clip space (-1 to +1)
                glBegin(obj.GL_QUADS);
                glVertex2f(-1, -1);
                glVertex2f( 1, -1);
                glVertex2f( 1,  1);
                glVertex2f(-1,  1);
                glEnd;
            end

            % --- 5. Reset GL state for PTB ---
            glUseProgram(0);
            glDisable(obj.GL_BLEND);
            glFinish;
            Screen('EndOpenGL', obj.winPtr);

            % --- 6. Nothing else to draw, ready for Screen('Flip') ---
            Screen(obj.winPtr,'BlendFunction',GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
        end

        function afterFrame(obj)
            obj.frameUpdate = obj.frameUpdate - 1;
            if obj.frameUpdate <= 0
                obj.sampleComponents();
            end
            %Screen('FillRect', obj.winPtr, obj.bgGrey);
            
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
            if isstruct(obj.shader)
                if isfield(obj.shader,'program') && obj.shader.program > 0
                    try Screen('Close', obj.shader.program); catch, end
                end
                if isfield(obj.shader,'vertFile') && exist(obj.shader.vertFile,'file'), delete(obj.shader.vertFile); end
                if isfield(obj.shader,'fragFile') && exist(obj.shader.fragFile,'file'), delete(obj.shader.fragFile); end
            end
            obj.shader = [];
            % if ~isempty(obj.offwin) && obj.offwin>0
            %     Screen('Close', obj.offwin);
            %     obj.offwin = [];
            % end
            try Screen('ColorRange', obj.winPtr, obj.oldmaximumvalue, obj.oldclampcolors, obj.oldapplyToDoubleInputMakeTexture); catch, end
        end

        function I = getImage(obj, rect, binSize)
            if nargin < 2 || isempty(rect),    rect = obj.screenRect; end
            if nargin < 3 || isempty(binSize), binSize = 1; end
            w = RectWidth(obj.screenRect);
            h = RectHeight(obj.screenRect);
            [xPix, yPix] = meshgrid((1:w) - (w+1)/2, (1:h) - (h+1)/2);
            Xdeg =  xPix / obj.pixPerDeg;
            Ydeg = -yPix / obj.pixPerDeg;
            acc = zeros(h, w, 'double');
            for j = 1:obj.K
                fx  = obj.current.fx(j); fy = obj.current.fy(j);
                phi = obj.current.phase(j);
                acc = acc + sin(2*pi*(fx.*Xdeg + fy.*Ydeg) + phi) * (obj.current.amp(j));
            end
            Ilin = obj.bgGrey + acc;
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


function [sx, sy, info] = pickHartleyStridesFromNs(Wdeg,Hdeg,FmaxX,FmaxY,ns,varargin)
% pickHartleyStridesFromNs  —  Simplified robust stride picker (single ns)
% ----------------------------------------------------------------------
% INPUTS
%   Wdeg,Hdeg   : screen width / height (deg)
%   FmaxX,FmaxY : band limits in cpd
%   ns          : target lattice samples per axis (including DC)
%
% OPTIONS
%   'equalStride' (default=false)
%   'FmaxRadial'  (optional cutoff in cpd)
%   'logRadial'   (optional struct with Rmin,Rmax,nR,nTheta)
%
% OUTPUT
%   sx, sy : integer strides (in screen pixels)
%   info   : struct with lattice metadata
%
% NOTES
%   - ns rounded to odd, min=3
%   - returns full lattice if ns exceeds available bandwidth
%
% AUTHOR
%   2025 Declan with help from GPT-5
% ----------------------------------------------------------------------

p = inputParser;
addParameter(p,'equalStride',false,@islogical);
addParameter(p,'FmaxRadial',[],@(x) isempty(x)||isscalar(x));
addParameter(p,'logRadial',[],@(x) isempty(x)||isstruct(x));
parse(p,varargin{:});
opt = p.Results;

% ----- Normalize ns -----
if isinf(ns)
    ns_eff = Inf;
elseif ns < 3
    ns_eff = 3;
elseif mod(ns,2)==0
    ns_eff = ns+1;
else
    ns_eff = ns;
end

% ----- Frequency caps -----
Kx_max = floor(Wdeg * FmaxX);
Ky_max = floor(Hdeg * FmaxY);

if isinf(ns_eff)
    sx = 1; sy = 1; mode = 'full';
elseif ns_eff >= min(2*Kx_max+1, 2*Ky_max+1)
    sx = 1; sy = 1; mode = 'full';
else
    m = (ns_eff - 1)/2;
    sx_lo = max(1, ceil(Kx_max/(m+1)));
    sx_hi = max(sx_lo, floor(Kx_max/m));
    sy_lo = max(1, ceil(Ky_max/(m+1)));
    sy_hi = max(sy_lo, floor(Ky_max/m));
    sxCand = sx_lo:sx_hi;
    syCand = sy_lo:sy_hi;

    bestErr = Inf;
    for sx_ = sxCand
        for sy_ = syCand
            err = abs(log((sx_/Wdeg)/(sy_/Hdeg)));
            if err < bestErr
                bestErr = err; sx = sx_; sy = sy_;
            end
        end
    end
    mode = 'sampled';
end

% ----- Equal-stride refinement -----
if opt.equalStride && strcmp(mode,'sampled')
    dfx_tgt = 2*FmaxX/(ns_eff-1);
    dfy_tgt = 2*FmaxY/(ns_eff-1);
    step_cpd = min(dfx_tgt, dfy_tgt);
    sx_try = round(step_cpd*Wdeg);
    sy_try = round(step_cpd*Hdeg);
    bestErr = Inf;
    for sx_ = max(1,sx_try-1):sx_try+1
        for sy_ = max(1,sy_try-1):sy_try+1
            err = abs(log((sx_/Wdeg)/(sy_/Hdeg)));
            if err < bestErr
                bestErr = err; sx = sx_; sy = sy_;
            end
        end
    end
    mode = [mode '_equal'];
end

% ----- Derived grid -----
fx_step = sx/Wdeg;
fy_step = sy/Hdeg;
nx = 2*floor(Kx_max/sx)+1;
ny = 2*floor(Ky_max/sy)+1;
N_total = nx*ny - 1;

kx = (-floor(nx/2):floor(nx/2))*sx;
ky = (-floor(ny/2):floor(ny/2))*sy;

% ----- Radial cutoff -----
if ~isempty(opt.FmaxRadial)
    [KX,KY] = meshgrid(kx/Wdeg, ky/Hdeg);
    R = sqrt(KX.^2 + KY.^2);
    N_disk = nnz(R<=opt.FmaxRadial)-1;
else
    N_disk = NaN;
end

% ----- Optional log-radial -----
coords = [];
N_log = NaN;
if ~isempty(opt.logRadial)
    lr = opt.logRadial;
    if ~isfield(lr,'nR'), lr.nR=6; end
    if ~isfield(lr,'nTheta'), lr.nTheta=12; end
    rhoTarget = logspace(log10(lr.Rmin),log10(lr.Rmax),lr.nR);
    theta = linspace(0,2*pi-(2*pi/lr.nTheta),lr.nTheta);  % full-plane coverage
    uppergrace = 10^(log10(lr.Rmax)+median(diff(log10(rhoTarget)))/2);
    for r = rhoTarget
        for t = theta
            fx = r*cos(t); fy = r*sin(t);
            kx_snap = round(fx*Wdeg); ky_snap = round(fy*Hdeg);
            fx_hat = kx_snap/Wdeg; fy_hat = ky_snap/Hdeg;
            rho_hat = hypot(fx_hat,fy_hat);
            if (kx_snap==0 && ky_snap==0), continue; end
            if rho_hat<lr.Rmin || rho_hat>uppergrace, continue; end
            %if (ky_snap<0)||(ky_snap==0 && kx_snap<=0), continue; end
            coords(end+1,:) = [fx_hat fy_hat rho_hat atan2(fy_hat,fx_hat)];
        end
    end
    coords = unique(round(coords,6),'rows');
    N_log = size(coords,1);
end

info = struct('ns',ns_eff,'mode',mode,'sx',sx,'sy',sy, ...
    'fx_step',fx_step,'fy_step',fy_step, ...
    'nx',nx,'ny',ny,'N_total',N_total,'N_disk',N_disk, ...
    'Kx_max',Kx_max,'Ky_max',Ky_max, ...
    'KX_screen',kx,'KY_screen',ky, ...
    'KX_cpd',kx/Wdeg,'KY_cpd',ky/Hdeg, ...
    'logCoords',coords,'N_log',N_log);
end