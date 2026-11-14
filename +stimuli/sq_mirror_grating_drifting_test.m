classdef sq_mirror_grating_drifting < stimuli.stimulus
    % Editing to create a pair of mirrored drifting square grating, text
    % Rect needs to be carefully split at 'position' and cropped to the
    % edges of the screen, phase set to 180-phase and all other parameters 
    % are matched. Only copy the texture at time to draw (use the same tex)

    %GRATING_DRIFTING draws drifting gratings and updates when they're on
    % and off
    %  Can run full-field or apertured
    % Sample code:
    % Paste in this code snippet to see how to use, and demonstrate the
    % seed reconstruction
    %     grat = stimuli.grating_drifting(winPtr, ...
    %         'numDirections', 16, ...
    %         'minSF', 1, ...
    %         'numOctaves', 3, ...
    %         'pixPerDeg', S.pixPerDeg, ...
    %         'speeds', 1, ...
    %         'position', [500 250], ...
    %         'screenRect', S.screenRect, ...
    %         'diameter', 10, ...
    %         'durationOn', 50, ...
    %         'durationOff', 40, ...
    %         'isiJitter', 10, ...
    %         'contrasts', 0.25, ...
    %         'randomizePhase', true);
    %     
    %     grat.beforeTrial()
    %     grat.updateTextures()
    %
    %     t0 = GetSecs;
    %     while GetSecs < t0 +5 % runs 5 seconds of grating stimulus
    %         grat.afterFrame()
    %         grat.beforeFrame()
    %         Screen('Flip', winPtr, 0);
    %     end

    
    properties
        winPtr % PTB window pointer
        
        % properties of the stimulus generation process
        minSF double % minimum spatial frequency
        numOctaves double % number of spatial frequency octaves
        numDirections double % number of orientations
        contrasts double % list of contrast
        
        % Note: these three parameters (above) can be overridden to produce
        % any combo of orientations and spatial frequencies using the
        % parameters below
        
        directions double       % list of directions
        speeds double
        speed=0
        spatialFrequencies double % list of spatial frequencies
        randomizePhase logical
        durationOn double  % duration a grating is on (frames)
        durationOff double % inter-stimulus interval (frames)
        isiJitter double % amount of jitter to add to the isi (frames)
        position double
        diameter double
        
        % --- internally used paramters
        tex         % the texture object
        texRect     % texture object rect
        screenRect
        frameRate
        pixPerDeg double
        orientation=0 % orientation of current grating
        cpd=0 % cycles per degree of current grating
        contrast=0 % contrast of current grating
        frameUpdate % counter for updating the frame
        phase=0 % phase of the current grating
        dphase=0 % current phase step
        
    end
    
    methods
        function obj = sq_mirror_grating_drifting(winPtr, varargin)
            % The constructor
            % build the object with required properties
            
            obj = obj@stimuli.stimulus();
            obj.winPtr = winPtr;
            
            ip = inputParser();
            ip.addParameter('minSF', 1)
            ip.addParameter('numOctaves', 5)
            ip.addParameter('numDirections', 16)
            ip.addParameter('speeds', 5) % phase shift per frame
            ip.addParameter('pixPerDeg', [])
            ip.addParameter('frameRate', [])
            ip.addParameter('position', [500 500])
            ip.addParameter('diameter', inf) % inf = fullfield
            ip.addParameter('durationOn', 10)
            ip.addParameter('durationOff', 10)
            ip.addParameter('isiJitter', 5)
            ip.addParameter('screenRect', [])
            ip.addParameter('contrasts', 0.5)
            ip.addParameter('randomizePhase', false)
            
            ip.parse(varargin{:});
            
            % create procedural grating object
            obj.tex = stimuli.grating_procedural(obj.winPtr);
  
            obj.tex.range = 127; % TODO: bit depth shouldn't be hard coded
            obj.tex.square = true;
            obj.tex.gauss = false;
            obj.tex.bkgd = 127;

            
            args = ip.Results;
            props = fieldnames(args);
            for iField = 1:numel(props)
                obj.(props{iField}) = args.(props{iField});
            end
            
            if isempty(obj.pixPerDeg)
                warning('grating_drifting: I need the pixPerDeg to be accurate')
                obj.pixPerDeg = 37.5048;
            end
            
            if isempty(obj.frameRate)
                warning('grating_drifting: I need the frameRate to be accurate')
                obj.frameRate = 60;
            end
            
            % match the two gratings (some parameters automatically match
            % -- should we do this for all?)
            obj.tex.screenRect = obj.screenRect;
            % obj.tex.radius = round((obj.diameter/2)*obj.pixPerDeg);
            % if isinf(obj.tex.radius)
            %     obj.tex.radius=ceil(hypot(obj.screenRect(3),obj.screenRect(4))/2);
            % end

            % Half the width
            obj.tex.radius=obj.tex.radius/2;

            % Keep as max, then display only on half screen later
            obj.tex.radius=inf; %However this prepares a grating twice as wide that gets squished into the frame
            obj.tex.pixPerDeg = obj.pixPerDeg*2;
                        
            obj.frameUpdate = 0;
            
            % initialize direction and spatial frequency space
%             obj.directions = 0:(360/obj.numDirections):(360-(360/obj.numDirections));
            obj.directions = 0:(360/obj.numDirections):(360-(360/obj.numDirections));
            if obj.numOctaves>0
                obj.spatialFrequencies = obj.minSF * 2.^(0:obj.numOctaves-1);
            else
                obj.spatialFrequencies = obj.minSF;
            end
            obj.phase = 0;
            obj.contrast = 0; % initialize to off
        end
        
        function beforeTrial(obj)
            obj.setRandomSeed();
            obj.frameUpdate = 0;
            obj.contrast = 0;
            obj.phase = 0; 
        end
        
        function reset(obj)
            % resets object to the last seed with the proper state to
            % reproduce
            obj.rng.reset();
            obj.frameUpdate = 0;
            obj.contrast = 0;
            obj.phase = 0; 
        end
        
        function beforeFrame(obj)
            %Hard code, testing
            obj.tex.orientation=0;

            % Time to draw, first to split and offset,
            % Just doing x-axis
            pos0=obj.tex.position(1);
%             maxoffset=max(abs(pos0-obj.screenRect(3)));
            offset=obj.screenRect(3)/2;
            
            %Need to keep the same radius or the texture will be warped,
            %only position and phase are different. Initialise texture to
            %be a half screen wide

            pos1=pos0-offset;
            obj.tex.position(1)=pos1;

            %obj.tex.texRect = [1+pos1 1 obj.screenRect(3)/2+pos1 obj.screenRect(4)];
            obj.tex.texRect = [1 1 obj.screenRect(3)/(1+sin(obj.orientation)) obj.screenRect(4)/(1+cos(obj.orientation))];
            shift=pos1.*[sin(obj.orientation) cos(obj.orientation) sin(obj.orientation) cos(obj.orientation)];
            obj.tex.texRect=obj.tex.texRect+shift;

            %Draw first square wave
            obj.tex.beforeFrame();
            
            pos2=pos0+offset;
            phase1=obj.tex.phase;
            phase2=360-phase1;

            %Unfortunately, since the phase on the right hand side of the
            %texture is not the same as the left (as the width is not a
            %perfect multiple of the cycles) we need to shift by a fraction
            %of a cycle,
            %phshift= rem(obj.tex.texRect(3),obj.tex.cyc)*360;
            cycleinpixels=(obj.tex.cpd*obj.pixPerDeg);
            cyclespertexture=obj.tex.texRect(3)/cycleinpixels;
            %remaindercycles=cyclespertexture-floor(cyclespertexture);
            phshift= 360*cyclespertexture; %if left is at 0deg, right side of grating is at phshift
            %phase2=phase2+phshift;

            obj.tex.position(1)=pos2;

            %Just rotate 180
            obj.tex.phase=phase1;
            obj.tex.orientation=obj.tex.orientation+180;

            obj.tex.texRect = [obj.screenRect(3)/2+pos1 1 obj.screenRect(3)+pos1 obj.screenRect(4)];
            obj.tex.texRect = [obj.screenRect(3)/(1+sin(obj.orientation)) obj.screenRect(4)/(1+cos(obj.orientation)) obj.screenRect(3) obj.screenRect(4)];
            shift=pos1.*[sin(obj.orientation) cos(obj.orientation) sin(obj.orientation) cos(obj.orientation)];
            obj.tex.texRect=obj.tex.texRect+shift;

            %Draw mirrored wave
            obj.tex.beforeFrame();

            %Return parameters in texture obj back to original for updating
            obj.tex.position(1)=pos0;
            obj.tex.phase=phase1;
            obj.tex.orientation=obj.tex.orientation-180;
            
           

        end
        
        function afterFrame(obj)
            
            % frameUpdate can be 0, < 0 or > 0
            % frameUpdate = 0, select a new grating
            % frameUpdate > 0, draw grating and count down to 0
            % frameUpdate < 0, draw no grating and count up to 0
            if obj.frameUpdate==0
                
                % if grating was just "on" enter "off" mode
                if obj.contrast > 0 % grating is on, turn it off
                    
%                     obj.cpd = 0; % grating is blank (CPD = 0)
                    jitter = round(rand(obj.rng)*obj.isiJitter);
                    obj.frameUpdate = -(obj.durationOff + jitter); % new frame update is a negative number to indicate time off
                    obj.stimValue = 0; % turn stimulus off
                    obj.contrast = 0;
                    
                elseif obj.contrast == 0 % stimulus was just off
                    
                    obj.stimValue = 1; % turn stimulus off
                    
                    % spatial frequency
                    obj.cpd = randsample(obj.rng, obj.spatialFrequencies, 1);
                    
                    % orientation
                    if length(obj.directions)>1
                        obj.orientation = randsample(obj.rng, obj.directions, 1)+90; % orientation is 90° from direction
                    else
                        obj.orientation = obj.directions +90;
                    end
                    
                    if length(obj.speed)>1
                        obj.speed = randsample(obj.rng, obj.speeds, 1);
                    else
                        obj.speed = obj.speeds;
                    end

                    obj.dphase = obj.speed/obj.frameRate*obj.cpd*360;
                    
                    % phase
                    if obj.randomizePhase % randomize initial phase of grating
                        obj.phase = rand(obj.rng,1)*180; % phase
                    else
                        obj.phase = 0;
                    end
                    
                    obj.frameUpdate = obj.durationOn;
                    
                    obj.contrast = randsample(obj.rng, obj.contrasts, 1);

                end

            end
            
            obj.phase = obj.phase - obj.dphase;
            
            if obj.frameUpdate < 0
                obj.frameUpdate = obj.frameUpdate + 1;
            else
                obj.frameUpdate = obj.frameUpdate - 1;
            end
            
        end
        
        function updateTextures(obj, varargin)
            % update grating texture
            obj.tex.updateTextures();
        end
        
        
          
        function CloseUp(obj)
            if ~isempty(obj.tex)
                obj.tex.CloseUp();
            end
        end
        
        
        function I = getImage(obj, rect, binSize)
            % GETIMAGE returns the image that was shown without calling PTB
            % I = getImage(obj, rect)
            if nargin < 3
                binSize = 1;
            end
            
            I = obj.tex.getImage(rect, binSize);
            
        end
        
        
        % --- GET / SET methods
        % we use get/set methods for properties that are shared by the
        % procedural grating texture and the drifting grating object
        
        % Phase
        function set.phase(obj, x)
            obj.phase = x;
            if ~isempty(obj.tex)
                obj.tex.phase = x;
            end
        end
        
        function x = get.phase(obj)
            if ~isempty(obj.tex)
                x = obj.tex.phase;
            else
                x = obj.phase;
            end
        end
        
        % Orientation
        function set.orientation(obj, x)
            obj.orientation = x;
            if ~isempty(obj.tex) %#ok<*MCSUP>
                obj.tex.orientation = x;
            end
        end
        
        function x = get.orientation(obj)
            if ~isempty(obj.tex)
                x = obj.tex.orientation;
            else
                x = obj.orientation;
            end
        end
        
        % Contrast
        function set.contrast(obj, x)
            obj.contrast = x;
            if ~isempty(obj.tex) %#ok<*MCSUP>
                obj.tex.transparent = x;
            end
        end
        
        function x = get.contrast(obj)
            if ~isempty(obj.tex)
                x = obj.tex.transparent;
            else
                x = obj.contrast;
            end
        end
        
        % Position
        function set.position(obj, x)
            obj.position = x;
            if ~isempty(obj.tex) %#ok<*MCSUP>
                obj.tex.position = x;
            end
        end
        
        function x = get.position(obj)
            if ~isempty(obj.tex)
                x = obj.tex.position;
            else
                x = obj.position;
            end
        end
        
        % spatial frequency
        function set.cpd(obj, x)
            obj.cpd = x;
            if ~isempty(obj.tex) %#ok<*MCSUP>
                obj.tex.cpd = x;
            end
        end
        
        function x = get.cpd(obj)
            if ~isempty(obj.tex)
                x = obj.tex.cpd;
            else
                x = obj.cpd;
            end
        end

        
    end
end

