classdef superimposed_sine_quartet < stimuli.stimulus
% Noise object wrapper to hold a set of 4 sine waves for testing
% sensitivity to correlations in V2. Change set on each frame, no drifting
% for rapid presentation

% Takes in generic call from protocol with shared co

% This could be done with multiple hnoise objects in the protocol but I
% worry about the interaction with the playback code




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
        contrastSF
        speed=0
        spatialFrequencies double % list of spatial frequencies
        randomizePhase logical
        durationOn double  % duration a grating is on (frames)
        durationOff double % inter-stimulus interval (frames)
        isiJitter double % amount of jitter to add to the isi (frames)
        position double
        diameter double
        prefori 
        
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

        %handles for sine wave stimuli
        hNoise1
        hNoise2
        hNoise3
        hNoise4
        
    end
    
    methods
        function obj = superimposed_sine_quartet(winPtr, varargin)
            % The constructor
            % build the object with required properties
            
            obj = obj@stimuli.stimulus();
            obj.winPtr = winPtr;
            
            ip = inputParser();
            ip.addParameter('minSF', 1)
            ip.addParameter('numOctaves', 5)
            ip.addParameter('numDirections', 16)
            ip.addParameter('numPhases', 12)
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

            %Need to recenter the orientation dist, even numbers get
            %centered on prefori so 12 dirs will be -7.5 7.5 22.5 etc
            if rem(ip.Results.numDirections,2)==0
                prefori=-90/ip.Results.numDirections; %half a division
            end

            

            % Generate stimuli from the grating_drifting_SFlinear class
            for gr=1:4
                obj.(['hNoise' num2str(gr)]) = stimuli.grating_drifting_SFlinear(winPtr, ...
                    'numDirections', ip.Results.numDirections, ...
                    'numPhases', ip.Results.numPhases, ...
                    'minSF', ip.Results.minSF, ...
                    'numOctaves', ip.Results.numOctaves, ...
                    'pixPerDeg', ip.Results.pixPerDeg, ...
                    'frameRate', ip.Results.frameRate, ...
                    'speeds', ip.Results.speeds, ...
                    'position', ip.Results.position, ...
                    'screenRect', ip.Results.screenRect, ...
                    'diameter', ip.Results.diameter, ...
                    'durationOn', ip.Results.durationOn, ...
                    'durationOff', ip.Results.durationOff, ...
                    'isiJitter', ip.Results.isiJitter, ...
                    'contrasts', ip.Results.contrasts, ...
                    'prefori', prefori, ...
                    'randomizePhase', false); % DO NOT RANDOMISE PHASE
            end
%             % Should each get their own rng
%             obj.hNoise2=copy(obj.hNoise1);
%                % obj.hNoise2.rng.Seed=obj.hNoise1.rng.Seed+1;
%             obj.hNoise3=obj.hNoise1;
%                % obj.hNoise3.rng.Seed=obj.hNoise1.rng.Seed+2;
%             obj.hNoise4=obj.hNoise1;
%                % obj.hNoise4.rng.Seed=obj.hNoise1.rng.Seed+3;
%            
            %We need the contrast to inversely vary with spatial frequency (1/f)
           
        end
        
        function beforeTrial(obj)
            obj.setRandomSeed();
            obj.hNoise1.setRandomSeed();
            obj.hNoise2.setRandomSeed();
            obj.hNoise3.setRandomSeed();
            obj.hNoise4.setRandomSeed();
            obj.frameUpdate = 0;

            obj.contrast = 0;
            obj.phase = 0; 
        end
        
        function reset(obj)
            % resets object to the last seed with the proper state to
            % reproduce
            obj.rng.reset();
            obj.hNoise1.rng.reset();
            obj.hNoise2.rng.reset();
            obj.hNoise3.rng.reset();
            obj.hNoise4.rng.reset();
            obj.frameUpdate = 0;
            obj.contrast = 0;
            obj.phase = 0; 
        end
        
        function beforeFrame(obj)
            obj.hNoise1.beforeFrame();
            obj.hNoise2.beforeFrame();
            obj.hNoise3.beforeFrame();
            obj.hNoise4.beforeFrame();
        end
        
        function afterFrame(obj)
            %Each sine wave updates individually?

            % frameUpdate can be 0, < 0 or > 0
            % , select a new grating
            % frameUpdate > 0, draw grating and count down to 0
            % frameUpdate < 0, draw no grating and count up to 0
            
            % For rapid presentation triggered by saccades, set to 0
            %
            % obj.frameUpdate = 0;
            if obj.frameUpdate==0
                % Time to update to new gratings (either to or from isi)

                % if grating was just "on" enter "off" mode
                if obj.contrast > 0 % grating is on, turn it off
                    
%                   obj.cpd = 0; % grating is blank (CPD = 0)
                    jitter = round(rand(obj.rng)*obj.isiJitter);
                    obj.frameUpdate = -(obj.durationOff + jitter); % new frame update is a negative number to indicate time off
                    obj.stimValue = 0; % turn stimulus off
                    obj.contrast = 0;
                    
                elseif obj.contrast == 0 % stimulus was just off
                    
                    obj.stimValue = 1; % turn stimulus off(?)
                    
                    %Tell swaves to update, there is surely a smart way for
                    %the waves to simply have a shared handle for this,
                    %maybe we should be passing a hNoise parent to each
                    obj.hNoise1.frameUpdate= 0;
                    obj.hNoise2.frameUpdate= 0;
                    obj.hNoise3.frameUpdate= 0;
                    obj.hNoise4.frameUpdate= 0;

                    obj.hNoise1.afterFrame();
                    obj.hNoise2.afterFrame();
                    obj.hNoise3.afterFrame();
                    obj.hNoise4.afterFrame();

                    obj.frameUpdate = obj.durationOn;
                    obj.hNoise1.frameUpdate= obj.durationOn;
                    obj.hNoise2.frameUpdate= obj.durationOn;
                    obj.hNoise3.frameUpdate= obj.durationOn;
                    obj.hNoise4.frameUpdate= obj.durationOn;
                    
                end

            end
            
            obj.phase = obj.phase - obj.dphase;

            %Let waves also update for drifting (if wanted)
            obj.hNoise1.afterFrame();
            obj.hNoise2.afterFrame();
            obj.hNoise3.afterFrame();
            obj.hNoise4.afterFrame();


               
            %Tick the clock
            if obj.frameUpdate < 0
                obj.frameUpdate = obj.frameUpdate + 1;
            else
                obj.frameUpdate = obj.frameUpdate - 1;
            end
        end
        
        function updateTextures(obj, varargin)
            % update grating texture
            %obj.tex.updateTextures();

            obj.hNoise1.updateTextures(); % create the procedural texture
            obj.hNoise2.updateTextures(); % create the procedural texture
            obj.hNoise3.updateTextures(); % create the procedural texture
            obj.hNoise4.updateTextures(); % create the procedural texture
        end
        
        
          
        function CloseUp(obj)
            if ~isempty(obj.hNoise1)
                obj.hNoise1.CloseUp();
                obj.hNoise2.CloseUp();
                obj.hNoise3.CloseUp();
                obj.hNoise4.CloseUp();
            end
        end
        
        
        function I = getImage(obj, rect, binSize)
            % GETIMAGE returns the image that was shown without calling PTB
            % I = getImage(obj, rect)
            if nargin < 3
                binSize = 1;
            end
            
            I1 = obj.hNoise1.getImage(rect, binSize);
            I2 = obj.hNoise2.getImage(rect, binSize);
            I3 = obj.hNoise3.getImage(rect, binSize);
            I4 = obj.hNoise4.getImage(rect, binSize);

            %need to be careful with casting to uint16 and summing
            I=I1+I2+I3+I4;
            
        end
        
        
    end
end