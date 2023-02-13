% dummy class for eyetracker (mimics the real thing)

classdef eyetrack_dummy < marmoview.behavior
  %******* basically is just a wrapper for a dummy eyetracker
  % returns the mouse position instead of the output from an eyetracker
  % 
  
  properties (SetAccess = private, GetAccess = public)
     
  end % properties

  % dependent properties, calculated on the fly...
  properties (SetAccess = public, GetAccess = public)
    EyeDump logical
    UseAsEyeTracker logical
  end
    
    methods
        function o = eyetrack_dummy(~,varargin) % h is the handle for the marmoview gui
            
            % initialise input parser
            p = inputParser;
            p.addParameter('EyeDump',true,@islogical); % default 1, do EyeDump
            p.addParameter('UseAsEyeTracker',true,@islogical); % default 1, use this as the eyetracker if set up
            p.parse(varargin{:});
            
            args = p.Results;
            o = o@marmoview.behavior(varargin{:});
            o.EyeDump = args.EyeDump;
            o.UseAsEyeTracker = args.UseAsEyeTracker;
            
            % configure the tracker and initialize...
        end
        
        function init(~,~)
        end

        function startfile(~,~)
            % no file is saved if using mouse
        end
        
        function closefile(~)
        end
        
        function unpause(~)
        end
        
        function pause(~)
        end
        
        function starttrial(~,varargin) %should be just two inputs but (~,~) throws and error?
        end
        
        function endtrial(~,varargin)
        end

        function close(~)
        end
        
        function [x,y] = getgaze(~)
            [x,y] = GetMouse;
            %other specs depend on screen and position
        end
        
        function r = getpupil(~)
            r = 1.0;
        end
        
        function sendcommand(~,~,~)
        end
        
    end % methods
    
    methods (Access = private)
        
    end % private emethods
    
end % classdef
