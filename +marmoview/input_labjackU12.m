% Code for sending arduino timing signals high and low, would be nice to
% also keep track of state of bits and read from the arduino

%IO0 - trial signal
%IO1 - on while running, start cams etc
%IO3 - photodiode


classdef input_labjackU12 < matlab.mixin.Copyable
    %******* basically is just a wrapper for a bunch of calls to the
    % arduino toolbox. based on code snippet from huklabBasics
    %     https://github.com/HukLab/huklabBasics/blob/584b5d277ba120b2e33e4f05c0657cacde67e1fa/%2Btreadmill/pmTread.m
    
    properties (SetAccess = public, GetAccess = public)
        Labjack % handle to the IOport 
        timeOpened double
        timeLastSample double
        maxFrames

        StartTimings %Holds the output hardware times for trial starts
        EndTimings %Holds the output hardware times for trial endings


    end
    
    properties (SetAccess = private, GetAccess = public)
        idnum = -1;  %Using first found U12
        demo = 0;  %Normal operations
        nextReward
        frameCounter double 
        IOstate %state of DIO pins
        UseAsEyeTracker
    end
    
    methods
        function self = input_labjackU12(varargin) % h is the handle for the marmoview gui
            
            % initialise input parser
            ip = inputParser;
            ip.addParameter('Labjack',[]);
            ip.addParameter('UseAsEyeTracker',false,@islogical); % default false
            ip.addParameter('maxFrames', 5e3)
            ip.parse(varargin{:});
            
            args = ip.Results;
            fields = fieldnames(args);
            for i = 1:numel(fields)
                self.(fields{i}) = args.(fields{i});
            end

            self.timeOpened = GetSecs();
            self.timeLastSample = self.timeOpened;
            
            self.frameCounter = 1;


            %Libraries for U12
            %low level exoserver
            header = '/home/huklab/exodriver/liblabjackusb/labjackusb.h';
            library = '/home/huklab/exodriver/liblabjackusb/liblabjackusb.so';
            loadlibrary(library,header);
            
            header  = '/home/huklab/Documents/ljacklm/libljacklm/ljacklm.h';
            library = '/home/huklab/Documents/ljacklm/libljacklm/libljacklm.so';
            loadlibrary(library,header);
            
            libisloaded('libljacklm')&libisloaded('liblabjackusb');
            functionList = libfunctions('libljacklm', '-full');
            
            
%             idnum = -1;  %Using first found U12
%             demo = 0;  %Normal operations
            errorString = [];
            
            %same setup as for output_labjack, hopefully they don't
            %interact...
            
            %Setting and reading directions and states
            trisD = hex2dec('00FF');  %Setting D0-7 to outputs, D8-15 to inputs (b0000000011111111)
            trisIO = hex2dec('3');  %Setting IO0-1 to outputs, IO2-3 to inputs (b0011)
            stateD = hex2dec('0000');  % 'eg : 00F0 sets D0-3 to low. D4-7 to high (b0000000011110000)
            stateIO = hex2dec('2');  %Setting IO0 to low. IO1 to high (b0010)
            updateDigital = 1;  %Updating D and IO lines
            outputD = 0;  %Returns of the output registers for D0-D15
            [errorCode, idnum, trisD, stateD, stateIO, outputD] = calllib('libljacklm','DigitalIO', self.idnum, self.demo, trisD, trisIO, stateD, stateIO, updateDigital, outputD);
            if(errorCode ~= 0)
                calllib('libljacklm','GetErrorString',errorCode, errorString);
                disp(['DigitalIO (update) error ' num2str(errorCode) ' : ' char(System.String(errorString))])
                return
            end

            self.IOstate.time(self.frameCounter,:) = nan(self.maxFrames,1);
            self.IOstate.trisD(self.frameCounter,:) = nan(self.maxFrames,1);
            self.IOstate.stateD(self.frameCounter,:) = nan(self.maxFrames,1);
            self.IOstate.outputD(self.frameCounter,:) = nan(self.maxFrames,1);
            self.IOstate.stateIO(self.frameCounter,:) = nan(self.maxFrames,1);

        end
        
        
    end % methods
    
    methods (Access = public)
        
        function out = afterFrame(self, currentTime, rewardState)
            
            t(1)=GetSecs;
            % Only reading current directions (D lines only) and states
            trisD = 0;
            trisIO = 0;
            stateD = 0;
            stateIO = 0;
            updateDigital = 0;  %Only read performed
            outputD=0;
            [errorCode, idnum, trisD, stateD, stateIO, outputD] = calllib('libljacklm','DigitalIO',self.idnum, self.demo, trisD, trisIO, stateD, stateIO, updateDigital, outputD);
            if(errorCode ~= 0)
                calllib('libljacklm','GetErrorString',errorCode, errorString);
                disp(['DigitalIO (read) error ' num2str(errorCode) ' : ' char(System.String(errorString))])
                return
            end
            
            
            self.IOstate.time(self.frameCounter,:)=currentTime;
            self.IOstate.trisD(self.frameCounter,:)=trisD;%dec2hex(trisD, 4);
            self.IOstate.stateD(self.frameCounter,:)=stateD;%dec2hex(stateD, 4);
            self.IOstate.outputD(self.frameCounter,:)=outputD;%dec2hex(outputD, 4);
            self.IOstate.stateIO(self.frameCounter,:) = stateIO;%dec2hex(stateIO, 1);
            t(2)=GetSecs; 

   
            self.frameCounter = self.frameCounter + 1;
            out=[];
        end 

        function startfile(self,~)
        end    
        
        function closefile(self,~)
        end        
        
        function init(self,~)
        end

        function readinput(self,~)
        end

        function starttrial(self,STARTCLOCK,STARTCLOCKTIME)
            self.frameCounter = 1;
            self.IOstate.time(self.frameCounter,:) = nan(self.maxFrames,1);
            self.IOstate.trisD(self.frameCounter,:) = nan(self.maxFrames,1);
            self.IOstate.stateD(self.frameCounter,:) = nan(self.maxFrames,1);
            self.IOstate.outputD(self.frameCounter,:) = nan(self.maxFrames,1);
            self.IOstate.stateIO(self.frameCounter,:) = nan(self.maxFrames,1);
     
        end

        function endtrial(self,ENDCLOCK,ENDCLOCKTIME,varargin)
        end

        function unpause(self,~)
        end
        
        function pause(~)
        end
        
        function timings=flipBit(self,bit,value)
            %pds.datapixx.flipBitVideoSync    flip a bit at the next VSync
            % no longer flips on VideoSync -> slows everything down
% 
%             trisD =(2^(bit-1));
%             trisIO = 0;
%             stateD = value; 
%             stateIO = 0;
%             updateDigital = 1;  %
%             t(1)=GetSecs;
%             [errorCode, idnum, trisD, stateD, stateIO, outputD] = calllib('libljacklm','DigitalIO',idnum, demo, trisD, trisIO, stateD, stateIO, updateDigital, outputD);
%             if(errorCode ~= 0)
%                 calllib('libljacklm','GetErrorString',errorCode, errorString);
%                 disp(['DigitalIO (read) error ' num2str(errorCode) ' : ' char(System.String(errorString))])
%                 return
%             end
%             t(2)=GetSecs; 
%     

%            timings=[mean(t) 0 diff(t)];

            %Setting digital line IO0 to output-high
            channel = bit; %IO0
            writeD = 0; %Set IO line (>0 for D line)
            stateIO = value; %Output-High (>0 = high, 0 = low)
            t(1)=GetSecs;
            [errorCode, idnum] = calllib('libljacklm','EDigitalOut', self.idnum, self.demo, channel, writeD, stateIO);
            d%isp(['Setting digital line IO' num2str(channel) ' to output with state ' num2str(state)])
            if(errorCode ~= 0)
                calllib('libljacklm','GetErrorString', errorCode, errorString);
                disp(['EDigitalOut error ' num2str(errorCode) ' : ' char(System.String(errorString))])
                return
            end
            t(2)=GetSecs; 
            timings=[mean(t) 0 diff(t)];
        end

        function reset(self)
            %Setting and reading directions and states
                trisD = hex2dec('00FF');  %Setting D0-7 to outputs, D8-15 to inputs (b0000000011111111)
                trisIO = hex2dec('3');  %Setting IO0-1 to outputs, IO2-3 to inputs (b0011)
                stateD = hex2dec('0000');  % 'eg : 00F0 sets D0-3 to low. D4-7 to high (b0000000011110000)
                stateIO = hex2dec('2');  %Setting IO0 to low. IO1 to high (b0010)
                updateDigital = 1;  %Updating D and IO lines
                outputD = 0;  %Returns of the output registers for D0-D15
                [errorCode, idnum, trisD, stateD, stateIO, outputD] = calllib('libljacklm','DigitalIO', self.idnum, self.demo, trisD, trisIO, stateD, stateIO, updateDigital, outputD);
                if(errorCode ~= 0)
                    calllib('libljacklm','GetErrorString',errorCode, errorString);
                    disp(['DigitalIO (update) error ' num2str(errorCode) ' : ' char(System.String(errorString))])
                    return
                end
            end
        
        function close(self)



            
            if ~isempty(self.idnum)
                [errorCode]=calllib('libljacklm','CloseLabJack',self.idnum);
                self.idnum = [];
            end
        end
    end % private methods
    
    methods (Static)
       
        
    end
    
end % classdef
