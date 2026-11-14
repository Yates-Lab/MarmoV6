function varargout = zebranoise_util(varargin)
    % UTIL - Collection of utility functions for Zebra noise generation
    % This file contains MATLAB ports of the Python util.py functions
    
    if nargin < 1
        error('util:noFunction', 'Must specify a function name');
    end
    
    func_name = varargin{1};
    args = varargin(2:end);
    
    switch func_name
        case 'filter_frames'
            varargout{1} = filter_frames(args{:});
        case 'apply_filters'
            varargout{1} = apply_filters(args{:});
        case 'filter_frames_index_function'
            varargout{1} = filter_frames_index_function(args{:});
        case 'discretize'
            varargout{1} = discretize(args{:});
        case 'generate_frames'
            varargout{1} = generate_frames(args{:});
        otherwise
            error('util:unknownFunction', 'Unknown function: %s', func_name);
    end
end

function im = filter_frames(im, filt, varargin)
    % Apply a filter/transformation to an image batch
    % 
    % Parameters:
    % im - 3D float array, values in [0,1], frames to filter
    % filt - string, the name of the filter
    % varargin - extra arguments passed to the filter
    %
    % Returns:
    % im - 3D float array, values in [0,1], filtered noise movie
    
    args = varargin;
    
    switch filt
        case 'threshold'
            im = single(im > args{1});
        case 'softthresh'
            im = 1./(1 + exp(-args{1}*(im - 0.5)));
        case 'comb'
            im = single(mod(floor(im./args{1}), 2) == 1);
        case 'invert'
            im = 1 - im;
        case 'reverse'
            im = im; % We need to use filter_index_function for this
        case 'blur'
            % Apply Gaussian filter to each frame
            for i = 1:size(im, 3)
                im(:,:,i) = imgaussfilt(im(:,:,i), args{1}, 'Padding', 'circular');
            end
        case 'wood'
            im = mod(im, args{1}) / args{1};
        case 'center'
            im = 1 - (abs(im - 0.5) * 2);
        case 'photodiode'
            s = args{1};
            im(1:s, end-s+1:end, 1:2:end) = 0;
            im(1:s, end-s+1:end, 2:2:end) = 1;
        case 'photodiode_anywhere'
            x = args{1} + 1; % Convert to 1-based indexing
            y = args{2} + 1;
            s = args{3};
            im(y:y+s-1, x:x+s-1, 1:2:end) = 0;
            im(y:y+s-1, x:x+s-1, 2:2:end) = 1;
        case 'photodiode_b2'
            s = 125;
            im(1:s, end-s+1:end, 1:2:end) = 0;
            im(1:s, end-s+1:end, 2:2:end) = 1;
        case 'photodiode_fusi'
            s = 75;
            im(1:s, end-s+1:end, 1:2:end) = 0;
            im(1:s, end-s+1:end, 2:2:end) = 1;
        case 'photodiode_bscope'
            s = 100;
            im(end-s+1:end, 1:s, 1:2:end) = 0;
            im(end-s+1:end, 1:s, 2:2:end) = 1;
        otherwise
            if isa(filt, 'function_handle')
                im = filt(im);
            else
                error('Invalid filter specified: %s', filt);
            end
    end
end

function arr = apply_filters(arr, filters)
    % Apply a list of filters to an array
    for i = 1:length(filters)
        f = filters{i};
        if ischar(f) || isstring(f)
            n = f;
            args = {};
        else
            n = f{1};
            args = f(2:end);
        end
        arr = filter_frames(arr, n, args{:});
    end
end

function index_func = filter_frames_index_function(filters, nframes)
    % Reordering frames in the video based on the filter
    %
    % Parameters:
    % filters - cell array of strings or cell arrays (list of filters)
    % nframes - number of frames
    %
    % Returns:
    % function handle mapping int -> int (reindexing function)
    
    % Check if 'reverse' is in filters
    reverse_found = false;
    for i = 1:length(filters)
        if ischar(filters{i}) && strcmp(filters{i}, 'reverse')
            reverse_found = true;
            break;
        elseif iscell(filters{i}) && strcmp(filters{i}{1}, 'reverse')
            reverse_found = true;
            break;
        end
    end
    
    if reverse_found
        index_func = @(x) nframes - x + 1; % MATLAB is 1-based
    else
        index_func = @(x) x;
    end
end

function im = discretize(im)
    % Convert movie to an unsigned 8-bit integer
    %
    % Parameters:
    % im - 3D float array, values in [0,1], noise movie
    %
    % Returns:
    % 3D uint8 array, values in [0,255], noise movie
    
    im = im * 255;
    im = uint8(im);
end

function arr = generate_frames(xsize, ysize, tsize, timepoints, varargin)
    % Preprocess arguments before passing to the MEX implementation of Perlin noise
    %
    % Parameters:
    % xsize, ysize - image dimensions
    % tsize - total number of time points
    % timepoints - array of time indices to generate
    % varargin - optional parameters: levels, xyscale, tscale, xscale, yscale, fps, seed
    
    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'levels', 10);
    addParameter(p, 'xyscale', 0.5);
    addParameter(p, 'tscale', 1);
    addParameter(p, 'xscale', 1.0);
    addParameter(p, 'yscale', 1.0);
    addParameter(p, 'fps', 30);
    addParameter(p, 'seed', 0);
    parse(p, varargin{:});
    
    levels = p.Results.levels;
    xyscale = p.Results.xyscale;
    tscale = p.Results.tscale;
    xscale = p.Results.xscale;
    yscale = p.Results.yscale;
    fps = p.Results.fps;
    seed = p.Results.seed;
    
    XYSCALEBASE = 100;
    
    % Use the temporal scale and number of timepoints to compute how many
    % units to make the stimulus across the temporal dimension
    tunits = floor(tsize / (tscale * (fps/30)));
    if tunits >= 4096
        error('Too many time points. Either make the tscale larger or tsize smaller');
    end
    
    ts_all = single((0:tsize-1) / (tscale * (fps/30)));
    ratio = floor(xsize/ysize * XYSCALEBASE);
    
    % Create coordinate arrays (convert to 0-based for MEX compatibility)
    x_coords = single((0:xsize-1) / ysize / xscale);
    y_coords = single((0:ysize-1) / ysize / yscale);
    t_coords = ts_all(timepoints + 1); % Convert to 1-based indexing, then back to 0-based
    
    % Call MEX function (assuming it exists)
    % make_perlin_mex should be the MEX version of _perlin.make_perlin
    try
        arr = stimuli.make_perlin_mex(x_coords, y_coords, t_coords, ...
                             'octaves', levels, ...
                             'persistence', xyscale, ...
                             'repeatx', ratio, ...
                             'repeaty', XYSCALEBASE, ...
                             'repeatz', tunits, ...
                             'base', seed);
        
        % MEX now outputs correct format [ysize, xsize, tsize]
        % Just ensure we have the right dimensionality for single frames
        if length(timepoints) == 1
            arr = arr(:, :, 1); % Extract single frame
        end
        
    catch ME
        if contains(ME.message, 'make_perlin_mex') || contains(ME.message, 'not yet implemented')
            % Fallback to MATLAB implementation if MEX not available
            warning('MEX function make_perlin_mex not available. Using MATLAB fallback.');
            arr = stimuli.perlin_noise_matlab(x_coords, y_coords, t_coords, ...
                                     'octaves', levels, ...
                                     'persistence', xyscale, ...
                                     'repeatx', ratio, ...
                                     'repeaty', XYSCALEBASE, ...
                                     'repeatz', tunits, ...
                                     'base', seed);
            % Ensure correct output format
            if length(timepoints) == 1
                arr = arr(:, :, 1); % Single frame
            end
        else
            rethrow(ME);
        end
    end
end


