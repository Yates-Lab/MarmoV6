% wrapper class for treadmill
% 4/28/2021 - Jake Yates
classdef treadmill_dummy < marmoview.behavior
    %******* dummy treadmill
    
    properties (SetAccess = public, GetAccess = public)
        timeOpened double
        timeLastSample double
        scaleFactor double
        rewardMode char
        locationSpace double
        maxFrames double
        rewardDist double
        rewardProb double

        UseAsEyeTracker
    end
    
    properties (SetAccess = private, GetAccess = public)
        frameCounter double 
        nextReward double
    end
    
    methods
        function self = treadmill_dummy(varargin) % h is the handle for the marmoview gui
            
            % initialise input parser
            ip = inputParser;
            ip.KeepUnmatched = true;
            ip.addParameter('scaleFactor', 1)
            ip.addParameter('rewardMode', 'dist')
            ip.addParameter('maxFrames', 5e3)
            ip.addParameter('rewardDist', inf)
            ip.addParameter('rewardProb', 0)
            ip.addParameter('UseAsEyeTracker', false)
            ip.parse(varargin{:});
            
            args = ip.Results;
            fields = fieldnames(args);
            for i = 1:numel(fields)
                self.(fields{i}) = args.(fields{i});
            end

            self.timeOpened = GetSecs();
            self.timeLastSample = self.timeOpened;
            
            self.frameCounter = 1;
            self.locationSpace = nan(self.maxFrames, 4); % time, loc, locScale, rewardState
            self.nextReward = self.rewardDist;
        end
        
        function out = afterFrame(self, currentTime, rewardState)
            
            self.locationSpace(self.frameCounter,1) = currentTime;
            self.locationSpace(self.frameCounter,4) = rewardState;
            % collect position data
            if mod(self.frameCounter,2) == 0 % iseven
                
                self.locationSpace(self.frameCounter,2:3) = GetMouse * [1 self.scaleFactor];
                
            elseif self.frameCounter == 1
                
                self.reset();
                
                self.locationSpace(self.frameCounter,2:3) = [0 0];
                
            else
                % same as previous frame
                self.locationSpace(self.frameCounter,2:3) = self.locationSpace(self.frameCounter-1,2:3);
            end
            
            % reward
            switch self.rewardMode
                
                case 'dist'
                    if self.locationSpace(self.frameCounter, 3) > self.nextReward && self.locationSpace(self.frameCounter-1, 3) < self.nextReward   
                        self.locationSpace(self.frameCounter,4) = self.locationSpace(self.frameCounter,4) + 1; % add one drop
                        self.nextReward = self.nextReward + self.rewardDist;
                    end  
                case 'time'
                    warning('treadmill_arduino: time reward not implemented')
            end
            
            out = self.locationSpace(self.frameCounter,4);
            self.frameCounter = self.frameCounter + 1;
        end 
        
        function starttrial(self,STARTCLOCK,STARTCLOCKTIME)
            reset(self)
        end

        function unpause(~,~)
        end

        function startfile(~,~)
            % no file is saved if using mouse
        end
        
        function closefile(~)
        end

        function readinput(self,~)
        end

        function endtrial(~,~,~,~)
        end

        
        function reset(self)
            self.frameCounter = 1;
            self.locationSpace(:) = nan;
        end
        
        function close(~)
            % dummy for compatibility with real treadmill objects
            
        end
        
    end 
    
    methods (Static)
       
        
    end
    
end % classdef
