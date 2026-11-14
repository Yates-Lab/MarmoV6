classdef grating_drifting_SFlinear < stimuli.stimulus
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
        numPhases double % number of orientations
        contrasts double % list of contrast
        contrastSF
        phaseSF
        prefori =0 % central ori to vary around
        
        % Note: these three parameters (above) can be overridden to produce
        % any combo of orientations and spatial frequencies using the
        % parameters below
        
        directions double       % list of directions
        phases double       % list of directions
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
        contrast=.25 % contrast of current grating
        frameUpdate % counter for updating the frame
        phase=0 % phase of the current grating
        dphase=0 % current phase step
        
    end
    
    methods
        function obj = grating_drifting_SFlinear(winPtr, varargin)
            % The constructor
            % build the object with required properties
            
            obj = obj@stimuli.stimulus();
            obj.winPtr = winPtr;
            
            ip = inputParser();
            ip.addParameter('minSF', 1)
            ip.addParameter('numOctaves', 5)
            ip.addParameter('numDirections', 16)
            ip.addParameter('numPhases', 4)
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
            ip.addParameter('prefori', 90)
            ip.addParameter('randomizePhase', false)
            
            ip.parse(varargin{:});
            
            % create procedural grating object
            obj.tex = stimuli.grating_procedural(obj.winPtr);
  
            obj.tex.range = 127; % TODO: bit depth shouldn't be hard coded
            obj.tex.square = false;
            obj.tex.gauss = true;
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
            obj.tex.radius = round((obj.diameter/2)*obj.pixPerDeg);
            obj.tex.pixPerDeg = obj.pixPerDeg;
                        
            obj.frameUpdate = 0;
            
            % initialize direction and spatial frequency space
            % hijacking this for orientation
%             obj.directions = 0:(360/obj.numDirections):(360-(360/obj.numDirections));
            obj.directions = 0:(180/obj.numDirections):(180-(180/obj.numDirections)); % varies around 90, +-90
            obj.directions = obj.directions - (180-(180/obj.numDirections))/2 + obj.prefori; % varies around 0 + obj.prefori, +-90

            % initialize phases
            obj.phases = 0:(360/obj.numPhases):(360-(360/obj.numPhases));

            
            %NOTE: numOctaves is number of samples, but isn't the span of octaves sampled, 
            % eg if you have numOctaves=2, you get two points that cover a
            % single doubling (ie 1 octave with samples at each end)
            obj.spatialFrequencies = obj.minSF * (1:2^(obj.numOctaves-1)); % * 2.^(0:obj.numOctaves-1);
            obj.contrastSF=1./(1:2^(obj.numOctaves-1));
            obj.phaseSF = 1:2^(obj.numOctaves-1);
            obj.phase = 0;
            %obj.contrast = 0; % initialize to off
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
            obj.tex.beforeFrame();
        end
        
        function afterFrame(obj)
            %obj.frameUpdate=0; %Override
            if obj.frameUpdate==0
            %Inherit from frameUpdate state from above, assume from here 
            % frameUpdate is zeros if this is called
              obj.stimValue = 1; % turn stimulus off
                    
                % spatial frequency
                sfdraw=randsample(obj.rng, 1:length(obj.spatialFrequencies), 1);
                obj.cpd = obj.spatialFrequencies(sfdraw);
                %obj.contrast = obj.contrastSF(sfdraw); %modifier for 1/f scaling
%                  obj.contrast = obj.contrast*randsample(obj.rng, obj.contrasts, 1); % randomise around 1/f
                obj.contrast = randsample(obj.rng, obj.contrasts, 1); % randomise around 1/f
                
                % orientation
                %obj.orientation = randsample(obj.rng, obj.directions, 1)+90; % orientation is 90° from direction
                obj.orientation  = obj.directions(randsample(obj.rng, length(obj.directions),1))+90; % allows ndirections =1
                obj.speed = randsample(obj.rng, obj.speeds, 1);
                
                %Each pattern created by overlaid sinusoids has a unique look, 
                %but if we phase shift all waves with relative phase shift (multiply by freqy) this preserves it. 
                % This is the same as just shifting in space, however each
                % wave has a different pseudorandom direction, so actual
                % shift is
                % We vary phases around this relative shift, but remember
                % absolute phase is randomised again by the eye position.
                %modifier for scaling phase with freq
                phasemod = obj.phaseSF(sfdraw);
                
                
                %Turns out Jude was already doing this to set the grating
                %drifts in terms of spatial speed rather than phase. Need
                %to also multiply by cosd(ori) in order to give phase
                %relative to a global spatial drift
                obj.dphase = 0;%obj.speed/obj.frameRate*obj.cpd*360*cosd(obj.orientation);
                
                %Phase is chosen from a list, randsample gives a weird
                %error for sampling a single value
                
                %We want to be able to pass a 'base' shift, per combination
                % around which the relative phase can vary
                obj.phase  = 90+phasemod*obj.phases(randsample(obj.rng, length(obj.phases),1));
                %obj.phase  = phasebase+phasemod*obj.phases(randsample(obj.rng, length(obj.phases),1));

                %obj.phase is the 'relative' phase at its own wavelength
                %and orientation, this shouldn't be adjusted(?)

               % obj.phase  = obj.phases(randsample(obj.rng, length(obj.phases),1));
               % disp(obj.phase )

                %obj.phase = randsample(obj.rng, obj.phases, 1);
                
                % phase
%                     if obj.randomizePhase % randomize initial phase of grating
%                         obj.phase = rand(obj.rng,1)*180; % phase
%                     else
%                         obj.phase = 0;
%                     end
                
            %obj.frameUpdate = obj.durationOn;
            else %update phase
%                 phasemod=find(obj.spatialFrequencies==obj.cpd); %SF multiple index
%                 obj.phase = obj.phase - phasemod*obj.dphase;
                obj.phase = obj.phase - obj.dphase;
            end

            %PAST 
%             % frameUpdate can be 0, < 0 or > 0
%             % frameUpdate = 0, select a new grating
%             % frameUpdate > 0, draw grating and count down to 0
%             % frameUpdate < 0, draw no grating and count up to 0
%             if obj.frameUpdate==0
%                 
%                 % if grating was just "on" enter "off" mode
%                 if obj.contrast > 0 % grating is on, turn it off
%                     
% %                     obj.cpd = 0; % grating is blank (CPD = 0)
%                     jitter = round(rand(obj.rng)*obj.isiJitter);
%                     obj.frameUpdate = -(obj.durationOff + jitter); % new frame update is a negative number to indicate time off
%                     obj.stimValue = 0; % turn stimulus off
%                     obj.contrast = 0;
%                     
%                 elseif obj.contrast == 0 % stimulus was just off
%                     
%                     obj.stimValue = 1; % turn stimulus off
%                     
%                     % spatial frequency
%                     sfdraw=randsample(obj.rng, 1:length(obj.spatialFrequencies), 1);
%                     obj.cpd = obj.spatialFrequencies(sfdraw);
%                     obj.contrast = obj.contrastSF(sfdraw); %modifier for 1/f scaling
%                     obj.contrast = obj.contrast*randsample(obj.rng, obj.contrasts, 1); % randomise around 1/f
%                     
%                     % orientation
%                     obj.orientation = randsample(obj.rng, obj.directions, 1)+90; % orientation is 90° from direction
%                     obj.speed = randsample(obj.rng, obj.speeds, 1);
%                     obj.dphase = obj.speed/obj.frameRate*obj.cpd*360;
% 
%                     %Phase is chosen from a list
%                     obj.phase = randsample(obj.rng, obj.phases, 1);
%                     
%                     % phase
% %                     if obj.randomizePhase % randomize initial phase of grating
% %                         obj.phase = rand(obj.rng,1)*180; % phase
% %                     else
% %                         obj.phase = 0;
% %                     end
%                     
%                     obj.frameUpdate = obj.durationOn;
%                     
%                 end
% 
%             end
%             
%             obj.phase = obj.phase - obj.dphase;
%             
%             if obj.frameUpdate < 0
%                 obj.frameUpdate = obj.frameUpdate + 1;
%             else
%                 obj.frameUpdate = obj.frameUpdate - 1;
%             end
%             
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

