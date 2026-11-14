classdef fourierplaid_procedural < stimuli.hartleyplaid_procedural
% Random-phase Fourier hyperplaid on a Hartley or snapped spiral lattice.
%
% Hartley-bank presets retain the inherited lattice. Spiral presets replace
% it with independently snapped, canonicalized, deduplicated physical axes.

    properties
        schemaVersion = 'fourierplaid_v1'
        phaseConvention = 'cos(2*pi*(kx*u+ky*v)+phaseRad)'
        trialSeed = NaN
        trialInitialState = []
        bankMode = 'hartley'
        bankDefinitionVersion = 'hartley_lattice_v1'
        spiralTargetCount = 2000
        spiralAxisCount = 0
        spiralMaxSF = 4
        spiralDensityExponent = -1
        spiralMinSF = 0
        spiralBankInfo = struct()
    end

    methods
        function obj = fourierplaid_procedural(winPtr, varargin)
            obj = obj@stimuli.hartleyplaid_procedural(winPtr, varargin{:});
        end

        function configureSpiralBank(obj, targetCount, maxSF, densityExponent, minSF, axisCount)
            % Replace the inherited rectangular Hartley bank with a
            % golden-angle bank designed in physical cycles/degree and
            % snapped to exact screen-periodic integer coordinates.
            if nargin < 2 || isempty(targetCount), targetCount = 2000; end
            if nargin < 3 || isempty(maxSF), maxSF = obj.FmaxX_cpd; end
            if nargin < 4 || isempty(densityExponent), densityExponent = -1; end
            if nargin < 5 || isempty(minSF), minSF = 0; end
            if nargin < 6 || isempty(axisCount), axisCount = 0; end
            validateattributes(targetCount, {'numeric'}, ...
                {'scalar','integer','>=',obj.K});
            validateattributes(maxSF, {'numeric'}, ...
                {'scalar','real','finite','positive'});
            validateattributes(densityExponent, {'numeric'}, ...
                {'scalar','real','finite','>=',-2});
            validateattributes(minSF, {'numeric'}, ...
                {'scalar','real','finite','nonnegative','<',maxSF});
            validateattributes(axisCount, {'numeric'}, ...
                {'scalar','integer','nonnegative'});
            obj.bankMode = 'golden_spiral_snap';
            obj.bankDefinitionVersion = 'golden_spiral_nearest_dedup_v2';
            obj.spiralTargetCount = double(targetCount);
            obj.spiralAxisCount = double(axisCount);
            obj.spiralMaxSF = double(maxSF);
            obj.spiralDensityExponent = double(densityExponent);
            obj.spiralMinSF = double(minSF);
            obj.bank = obj.buildBank();
            obj.bankReady = true;
        end

        function bank = buildBank(obj)
            if strcmp(obj.bankMode, 'golden_spiral_snap')
                Wdeg = RectWidth(obj.screenRect) / obj.pixPerDeg;
                Hdeg = RectHeight(obj.screenRect) / obj.pixPerDeg;
                [bank, obj.spiralBankInfo] = ...
                    stimuli.buildGoldenSpiralFourierBank(Wdeg, Hdeg, ...
                    obj.spiralTargetCount, obj.spiralMaxSF, ...
                    obj.spiralDensityExponent, obj.spiralMinSF, ...
                    obj.spiralAxisCount);
            else
                bank = buildBank@stimuli.hartleyplaid_procedural(obj);
            end
        end

        function initGLAndShader(obj)
            if ~obj.gl_inited
                PsychDefaultSetup(2);
                obj.gl_inited = true;
            end

            [scriptPath, ~, ~] = fileparts(mfilename('fullpath'));
            if isempty(scriptPath), scriptPath = pwd; end
            obj.shader.vertFile = fullfile(scriptPath, 'fourierplaid_procedural.vert');
            obj.shader.fragFile = fullfile(scriptPath, 'fourierplaid_procedural.frag');
            if ~exist(obj.shader.vertFile, 'file') || ~exist(obj.shader.fragFile, 'file')
                error('The committed fourierplaid shader files are missing.');
            end

            obj.shader.program = LoadGLSLProgramFromFiles( ...
                {obj.shader.vertFile, obj.shader.fragFile});
            if obj.shader.program <= 0
                error('Failed to compile/link fourierplaid shaders.');
            end
            glUseProgram(obj.shader.program);
            obj.shader.loc_kx    = glGetUniformLocation(obj.shader.program, 'kx');
            obj.shader.loc_ky    = glGetUniformLocation(obj.shader.program, 'ky');
            obj.shader.loc_phase = glGetUniformLocation(obj.shader.program, 'phaseRad');
            obj.shader.loc_amp   = glGetUniformLocation(obj.shader.program, 'amplitude');
            glUseProgram(0);
        end

        function beforeTrial(obj)
            % One ordinary stream is used sequentially for all draws. The
            % explicit history, not an attempt at cross-condition matching,
            % is the source of truth for the displayed sequence.
            obj.setRandomSeed();
            obj.trialSeed = obj.rng.Seed;
            obj.trialInitialState = obj.rng.State;
            obj.frameUpdate = 0;
            if ~obj.bankReady
                obj.bank = obj.buildBank();
                obj.initGLAndShader();
                obj.bankReady = true;
            end
            obj.sampleComponents();
        end

        function sampleComponents(obj)
            nAxes = numel(obj.bank)/2;
            if obj.K > nAxes && obj.uniquePerFrame
                error('K exceeds the number of unique Fourier axes in the bank.');
            end
            if obj.uniquePerFrame
                baseIdx = randperm(obj.rng, nAxes, obj.K);
            else
                baseIdx = randi(obj.rng, nAxes, [1 obj.K]);
            end

            chooseOpposite = rand(obj.rng, 1, obj.K) > 0.5;
            idx = baseIdx;
            idx(chooseOpposite) = arrayfun( ...
                @(i) obj.bank(i).opp, baseIdx(chooseOpposite));

            fx = arrayfun(@(i) obj.bank(i).fx, idx);
            fy = arrayfun(@(i) obj.bank(i).fy, idx);
            kx = arrayfun(@(i) obj.bank(i).kx, idx);
            ky = arrayfun(@(i) obj.bank(i).ky, idx);

            obj.current.idx   = idx;
            obj.current.fx    = fx;
            obj.current.fy    = fy;
            obj.current.kx    = kx;
            obj.current.ky    = ky;
            obj.current.sf    = hypot(fx, fy);
            obj.current.ori   = rad2deg(mod(atan2(fy, fx), 2*pi));
            obj.current.phase = 2*pi*rand(obj.rng, 1, obj.K);
            obj.current.amp   = ones(1, obj.K) * ...
                obj.contrast / sqrt(max(obj.K, 1));
            obj.frameUpdate = obj.updateEveryNFrames;
        end

        function beforeFrame(obj)
            Screen('BeginOpenGL', obj.winPtr);
            glViewport(0, 0, RectWidth(obj.screenRect), RectHeight(obj.screenRect));
            glClearColor(obj.bgGrey, obj.bgGrey, obj.bgGrey, 1.0);
            glClear(hex2dec('00004000')); % GL_COLOR_BUFFER_BIT

            glEnable(obj.GL_BLEND);
            glBlendEquation(hex2dec('8006')); % GL_FUNC_ADD
            glBlendFunc(obj.GL_ONE, obj.GL_ONE);
            glUseProgram(obj.shader.program);

            for j = 1:obj.K
                glUniform1f(obj.shader.loc_kx, obj.current.kx(j));
                glUniform1f(obj.shader.loc_ky, obj.current.ky(j));
                glUniform1f(obj.shader.loc_phase, obj.current.phase(j));
                glUniform1f(obj.shader.loc_amp, obj.current.amp(j));
                glBegin(obj.GL_QUADS);
                glVertex2f(-1, -1);
                glVertex2f( 1, -1);
                glVertex2f( 1,  1);
                glVertex2f(-1,  1);
                glEnd;
            end

            glUseProgram(0);
            glDisable(obj.GL_BLEND);
            glFinish;
            Screen('EndOpenGL', obj.winPtr);
            Screen(obj.winPtr, 'BlendFunction', GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        end

        function I = getImage(obj, rect, binSize)
            if nargin < 2 || isempty(rect), rect = obj.screenRect; end
            if nargin < 3 || isempty(binSize), binSize = 1; end
            w = RectWidth(obj.screenRect);
            h = RectHeight(obj.screenRect);
            [xPix, yPix] = meshgrid((1:w)-(w+1)/2, (1:h)-(h+1)/2);
            Xdeg = xPix / obj.pixPerDeg;
            Ydeg = -yPix / obj.pixPerDeg;
            acc = zeros(h, w, 'double');
            for j = 1:obj.K
                theta = 2*pi*(obj.current.fx(j).*Xdeg + ...
                    obj.current.fy(j).*Ydeg) + obj.current.phase(j);
                acc = acc + obj.current.amp(j)*cos(theta);
            end
            Ilin = min(max(obj.bgGrey + acc, 0), 1);
            L = max(1, round(rect(1)-obj.screenRect(1)+1));
            T = max(1, round(rect(2)-obj.screenRect(2)+1));
            R = min(w, round(rect(3)-obj.screenRect(1)));
            B = min(h, round(rect(4)-obj.screenRect(2)));
            Ilin = Ilin(T:B, L:R);
            if binSize > 1
                hh = floor(size(Ilin,1)/binSize)*binSize;
                ww = floor(size(Ilin,2)/binSize)*binSize;
                Ilin = Ilin(1:hh,1:ww);
                Ilin = reshape(Ilin, binSize, hh/binSize, binSize, ww/binSize);
                Ilin = squeeze(mean(mean(Ilin,1),3));
            end
            I = uint8(round(Ilin*255));
        end

        function row = currentLogRowNumeric(obj, whenTimestamp)
            if nargin < 2, whenTimestamp = NaN; end
            row = [double(whenTimestamp), double(obj.K), ...
                double(obj.current.fx(:)).', double(obj.current.fy(:)).', ...
                double(obj.current.phase(:)).', double(obj.current.amp(:)).', ...
                double(obj.current.idx(:)).'];
        end

        function CloseUp(obj)
            % Shader sources are committed assets and must not be deleted.
            if ~isempty(obj.texHandles)
                for k = 1:numel(obj.texHandles)
                    if obj.texHandles(k) > 0
                        Screen('Close', obj.texHandles(k));
                    end
                end
            end
            obj.texHandles = [];
            obj.bankReady = false;
            if isstruct(obj.shader) && isfield(obj.shader, 'program') && ...
                    obj.shader.program > 0
                % A GLSL program is not a Psychtoolbox window/texture.
                % Screen('Close', program) can close an unrelated PTB
                % resource when the numeric handles happen to collide.
                openGLActive = false;
                try
                    Screen('BeginOpenGL', obj.winPtr);
                    openGLActive = true;
                    glUseProgram(0);
                    glDeleteProgram(obj.shader.program);
                    Screen('EndOpenGL', obj.winPtr);
                catch
                    if openGLActive
                        try Screen('EndOpenGL', obj.winPtr); catch, end
                    end
                end
            end
            obj.shader = [];
            try
                Screen('ColorRange', obj.winPtr, obj.oldmaximumvalue, ...
                    obj.oldclampcolors, obj.oldapplyToDoubleInputMakeTexture);
            catch
            end
        end
    end
end
