classdef zebranoise < stimuli.stimulus
    % ZEBRANOISE A MarmoView stimulus class for zebra noise generation
    %
    % This class provides zebra noise stimuli for use with MarmoView and PsychToolbox.
    % It generates Perlin noise frames with comb filtering applied, suitable for
    % real-time presentation using Screen('MakeTexture').
    %
    % Usage:
    %   stim = ZebraNoise();
    %   stim.xsize = 640;
    %   stim.ysize = 480;
    %   stim.duration = 10.0;  % seconds
    %   stim.setup(display_params);
    %   frame = stim.getFrame(frameNum);
    %   texture = Screen('MakeTexture', winPtr, frame);
    
    properties (Access = public)
        % Core parameters (matching zebra_noise.m)
        xsize = 640          % Width of stimulus in pixels
        ysize = 480          % Height of stimulus in pixels
        duration = 2.0       % Duration in seconds
        levels = 10          % Number of octaves for 1/f spectrum
        xyscale = 0.2        % Spatial scale of Perlin noise (0-1)
        tscale = 50          % Temporal scaling factor
        fps = 30             % Frames per second
        xscale = 1.0         % X dimension scaling
        yscale = 1.0         % Y dimension scaling
        seed = 0             % Random seed
        
        % Filter parameters
        comb_frequency = 0.08  % Comb filter frequency (default from zebra_noise)
        apply_comb = true      % Whether to apply comb filter
        
        % Generation strategy
        pregenerate = false    % If true, generate all frames at once; if false, generate on-demand
        cache_frames = false   % Whether to cache generated frames
    end
    
    properties (Access = private)
        tsize               % Total number of frames
        frame_cache         % Cache for generated frames
        get_index_func      % Function handle for frame reordering
        is_setup = false    % Whether stimulus has been set up
    end
    
    methods
        function obj = zebranoise(winPtr, varargin)
            % Constructor
            obj@stimuli.stimulus();
            
            % Parse optional parameters
            if nargin > 0
                for i = 1:2:length(varargin)
                    if isprop(obj, varargin{i})
                        obj.(varargin{i}) = varargin{i+1};
                    end
                end
            end

            % Setup the stimulus (called by MarmoView)
            
            % Calculate total number of frames
            obj.tsize = floor(obj.duration * obj.fps);
            
            % Adjust tscale for frame rate
            tscale_adjusted = obj.tscale * (obj.fps/30);
            textra = mod(tscale_adjusted - mod(obj.tsize, tscale_adjusted), tscale_adjusted);
            if textra > 0
                warning('ZebraNoise: Adding %d extra timepoints to make tscale a multiple of duration', textra);
                obj.tsize = obj.tsize + round(textra);
            end
            
            % Create frame reordering function (for reverse filter, etc.)
            filters = {};
            if obj.apply_comb
                filters{end+1} = {'comb', obj.comb_frequency};
            end
            obj.get_index_func = stimuli.zebranoise_util('filter_frames_index_function', filters, obj.tsize);
            
            % Initialize frame cache if needed
            if obj.cache_frames
                obj.frame_cache = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            end
            
            % Pre-generate all frames if requested
            if obj.pregenerate
                obj.pregenerateAllFrames();
            end
            
            obj.is_setup = true;
        end
        
        function frame = getFrame(obj, frameNum)
            % Get a single frame (1-based indexing)
            %
            % Parameters:
            % frameNum - int, frame number (1 to obj.tsize)
            %
            % Returns:
            % frame - uint8 matrix, ready for Screen('MakeTexture')
            
            if ~obj.is_setup
                error('ZebraNoise: Must call setup() before getFrame()');
            end
            
            if frameNum < 1 || frameNum > obj.tsize
                error('ZebraNoise: frameNum must be between 1 and %d', obj.tsize);
            end
            
            % Check cache first
            if obj.cache_frames && isKey(obj.frame_cache, frameNum)
                frame = obj.frame_cache(frameNum);
                return;
            end
            
            % Generate frame
            if obj.pregenerate
                % Should already be generated
                error('ZebraNoise: Pregenerated frames not found');
            else
                frame = obj.generateSingleFrame(frameNum);
            end
            
            % Cache if requested
            if obj.cache_frames
                obj.frame_cache(frameNum) = frame;
            end
        end
        
        function frame = generateSingleFrame(obj, frameNum)
            % Generate a single frame with filters applied
            
            % Get reordered frame index
            frame_idx = obj.get_index_func(frameNum);
            timepoint = frame_idx - 1; % Convert to 0-based indexing
            
            % Generate raw Perlin noise frame
            raw_frame = stimuli.zebranoise_util('generate_frames', obj.ysize, obj.xsize, obj.tsize, timepoint, ...
                           'levels', obj.levels, 'xyscale', obj.xyscale, 'tscale', obj.tscale, ...
                           'xscale', obj.xscale, 'yscale', obj.yscale, 'seed', obj.seed);
            
            % Apply comb filter if requested
            if obj.apply_comb
                filters = {{'comb', obj.comb_frequency}};
                filtered_frame = stimuli.zebranoise_util('apply_filters', raw_frame, filters);
            else
                filtered_frame = raw_frame;
            end
            
            % Discretize to uint8 (ready for PsychToolbox)
            frame = stimuli.zebranoise_util('discretize', filtered_frame(:,:,1));
        end
        
        function pregenerateAllFrames(obj)
            % Pre-generate all frames at once (memory intensive but faster access)
            
            fprintf('ZebraNoise: Pre-generating %d frames...\n', obj.tsize);
            
            % Generate all timepoints at once using MEX
            timepoints = 0:(obj.tsize-1); % 0-based indexing for MEX
            all_raw_frames = stimuli.zebranoise_util('generate_frames', obj.ysize, obj.xsize, obj.tsize, timepoints, ...
                                'levels', obj.levels, 'xyscale', obj.xyscale, 'tscale', obj.tscale, ...
                                'xscale', obj.xscale, 'yscale', obj.yscale, 'seed', obj.seed);
            
            % Apply filters and discretize all frames
            if obj.apply_comb
                filters = {{'comb', obj.comb_frequency}};
                all_filtered_frames = stimuli.zebranoise_util('apply_filters', all_raw_frames, filters);
            else
                all_filtered_frames = all_raw_frames;
            end
            
            % Store all frames in cache
            if ~obj.cache_frames
                obj.cache_frames = true;
                obj.frame_cache = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            end
            
            for i = 1:obj.tsize
                frame_idx = obj.get_index_func(i);
                discretized_frame = stimuli.zebranoise_util('discretize', all_filtered_frames(:,:,frame_idx));
                obj.frame_cache(i) = discretized_frame;
            end
            
            fprintf('ZebraNoise: Pre-generation complete.\n');
        end
        
        function n = getTotalFrames(obj)
            % Get total number of frames in the stimulus
            if ~obj.is_setup
                obj.tsize = floor(obj.duration * obj.fps);
            end
            n = obj.tsize;
        end
        
        function fps = getFrameRate(obj)
            % Get the frame rate of the stimulus
            fps = obj.fps;
        end
        
        function dur = getDuration(obj)
            % Get duration in seconds
            dur = obj.duration;
        end
        
        function clearCache(obj)
            % Clear the frame cache to free memory
            if obj.cache_frames
                obj.frame_cache = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            end
        end
        
        function info = getInfo(obj)
            % Get stimulus information
            info = struct();
            info.type = 'ZebraNoise';
            info.xsize = obj.xsize;
            info.ysize = obj.ysize;
            info.duration = obj.duration;
            info.fps = obj.fps;
            info.total_frames = obj.getTotalFrames();
            info.levels = obj.levels;
            info.xyscale = obj.xyscale;
            info.tscale = obj.tscale;
            info.seed = obj.seed;
            info.comb_frequency = obj.comb_frequency;
            info.apply_comb = obj.apply_comb;
            info.pregenerate = obj.pregenerate;
            info.cache_frames = obj.cache_frames;
        end
    end
    
    methods (Static)
        function demo()
            % Simple demo of the ZebraNoise stimulus
            fprintf('ZebraNoise Demo\n');
            fprintf('==============\n');
            
            % Create stimulus
            stim = ZebraNoise('xsize', 320, 'ysize', 240, 'duration', 1.0, ...
                            'seed', 42, 'cache_frames', true);
            
            % Setup (normally done by MarmoView)
            stim.setup([]);
            
            % Generate a few frames
            fprintf('Generating frames...\n');
            for i = 1:5
                frame = stim.getFrame(i);
                fprintf('Frame %d: size=%dx%d, range=[%d,%d]\n', i, ...
                       size(frame,1), size(frame,2), min(frame(:)), max(frame(:)));
            end
            
            % Show info
            info = stim.getInfo();
            disp('Stimulus info:');
            disp(info);
        end
    end
end