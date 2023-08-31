% wrapper class for treadmill
% 4/28/2021 - Jake Yates
classdef output_arduino < matlab.mixin.Copyable
    %******* basically is just a wrapper for a bunch of calls to the
    % arduino toolbox. based on code snippet from huklabBasics
    %     https://github.com/HukLab/huklabBasics/blob/584b5d277ba120b2e33e4f05c0657cacde67e1fa/%2Btreadmill/pmTread.m
    
    properties (SetAccess = public, GetAccess = public)
        arduinoUno % handle to the IOport 
        timeOpened double
        timeLastSample double
        scaleFactor double
        rewardMode char
        locationSpace double
        maxFrames double 
        rewardDist
        rewardProb
        UseAsEyeTracker logical


        offset
        wheelPos
        wheelPosRaw
    end
    
    properties (SetAccess = private, GetAccess = public)
        port
        baud
        nextReward
        frameCounter double 
    end
    
    methods
        function self = output_arduino(varargin) % h is the handle for the marmoview gui
            
            % initialise input parser
            ip = inputParser;
            ip.addParameter('port',[]);
            ip.addParameter('baud', 115200)
            ip.addParameter('scaleFactor', [])
            ip.addParameter('rewardMode', 'dist')
            ip.addParameter('maxFrames', 5e3)
            ip.addParameter('rewardDist', 94.25./15)
            ip.addParameter('rewardProb', 1)
            ip.addParameter('UseAsEyeTracker',false,@islogical); % default false
            ip.parse(varargin{:});
            
            args = ip.Results;
            fields = fieldnames(args);
            for i = 1:numel(fields)
                self.(fields{i}) = args.(fields{i});
            end

            config=sprintf('BaudRate=%d ReceiveTimeout=0.1', self.baud); %DTR=1 RTS=1 
        
            [self.arduinoUno, ~] = IOPort('OpenSerialPort', self.port, config);
            self.timeOpened = GetSecs();
            self.timeLastSample = self.timeOpened;
            
            self.frameCounter = 1;
%             self.locationSpace = nan(self.maxFrames, 5); % time, timestamp, loc, locScale, rewardState
%             
%             self.nextReward = self.rewardDist;
        end
        
        
    end % methods
    
    methods (Access = public)
        
        function out = afterFrame(self, currentTime, rewardState)
            
            self.frameCounter = self.frameCounter + 1;
        end 

        function startfile(~)
        end    
        
        function closefile(~)
        end

        
        
        function init(~,~)
        end

        function readinput(self,~)
        end

        function timings= starttrial(self,STARTCLOCK,STARTCLOCKTIME)
            % Send first bit high
            
            bitmask='0001';
            value=1;
            datastring = sprintf(['Value:' num2str(value,'%02.f') ', \t Bitmask:' bitmask ',']);
            t(1)=GetSecs;
            [nwritten, when, errmsg, prewritetime, postwritetime, lastchecktime] = IOPort('Write', self.arduinoUno, datastring, blocking=1);
            t(2)=GetSecs;   
    

            timings=[mean(t) when diff(t)];
            
        end

        function timings=endtrial(self,STARTCLOCK,STARTCLOCKTIME)
           % Send first bit low
            
            bitmask='0001';
            value=0;
            datastring = sprintf(['Value:' num2str(value,'%02.f') ', \t Bitmask:' bitmask ',']);
            t(1)=GetSecs;
            [nwritten, when, errmsg, prewritetime, postwritetime, lastchecktime] = IOPort('Write', self.arduinoUno, datastring, blocking=1);
            t(2)=GetSecs;   
    

            timings=[mean(t) when diff(t)];
        end

        function unpause(self,~)
        end
        
        function pause(~)
        end
        
        function timings=flipBit(self,bit,value)
            %pds.datapixx.flipBitVideoSync    flip a bit at the next VSync
            % no longer flips on VideoSync -> slows everything down

            bitmask=dec2bin(2^(bit-1));
            datastring = sprintf(['Value:' num2str(value,'%02.f') ', \t Bitmask:' bitmask ',']);
            t(1)=GetSecs;
            [nwritten, when, errmsg, prewritetime, postwritetime, lastchecktime] = IOPort('Write', self.arduinoUno, datastring, blocking=1);
            t(2)=GetSecs;   
    

            timings=[mean(t) when diff(t)];
        end

        function reset(self)
            %IOPort('Write', self.arduinoUno, 'reset');
            self.nextReward = self.rewardDist;
            self.frameCounter = 1;
            self.locationSpace(:) = nan;
            IOPort('Flush', self.arduinoUno);
        end
        
        function close(self)
            if ~isempty(self.arduinoUno)
                IOPort('Close', self.arduinoUno)
                self.arduinoUno = [];
            end
        end
    end % private methods
    
    methods (Static)
       
        
    end
    
end % classdef