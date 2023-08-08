% abstract class for eyetrackers

classdef eyetrack < matlab.mixin.Copyable & handle
  %******* basically is just a wrapper for a dummy eyetracker
  % 
  
  properties (SetAccess = private, GetAccess = public)
     
  end % properties

  % dependent properties, calculated on the fly...
  properties (SetAccess = public, GetAccess = public)
    EyeDump logical
    UseAsEyeTracker logical
    x
    y
  end
    
    methods
        function o = eyetrack(~,varargin) % h is the handle for the marmoview gui
            
            % initialise input parser
            p = inputParser;
            p.addParameter('EyeDump',true,@islogical); % default 1, do EyeDump
            p.addParameter('UseAsEyeTracker',true,@islogical); % default 1, do EyeDump
            
            p.parse(varargin{:});
            
            args = p.Results;
            o.EyeDump = args.EyeDump;
            o.UseAsEyeTracker = args.UseAsEyeTracker;
            
            % configure the tracker and initialize...
        end
        
        function init(~,~)
        end

        function readinput(self,~)
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
        
        function afterFrame(~,~)
        end

        function endtrial(~)
        end
        
        function [x,y] = getgaze(self,~)
            [x,y] = GetMouse;
            self.x = x;
            self.y = y;     
            %other specs depend on screen and position
        end
        
        function [x,y] = getinput(self,~)
            x = self.x;
            y = self.y;
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
