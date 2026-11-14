% Code for sending arduino timing signals high and low, would be nice to
% also keep track of state of bits and read from the arduino

classdef output_labjackU12 < matlab.mixin.Copyable
    %******* basically is just a wrapper for a bunch of calls to the
    % arduino toolbox. based on code snippet from huklabBasics
    %     https://github.com/HukLab/huklabBasics/blob/584b5d277ba120b2e33e4f05c0657cacde67e1fa/%2Btreadmill/pmTread.m
    
    properties (SetAccess = public, GetAccess = public)
        Labjack % handle to the IOport 
        timeOpened double
        timeLastSample double


        StartTimings %Holds the output hardware times for trial starts
        EndTimings %Holds the output hardware times for trial endings


    end
    
    properties (SetAccess = private, GetAccess = public)
        idnum = -1;  %Using first found U12
        demo = 0;  %Normal operations
        nextReward
        frameCounter double 
        state %state of DIO pins
        UseAsEyeTracker
    end
    
    methods
        function self = output_labjackU12(varargin) % h is the handle for the marmoview gui
            
            % initialise input parser
            ip = inputParser;
            ip.addParameter('Labjack',[]);
            ip.addParameter('UseAsEyeTracker',false,@islogical); % default false
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
            
            %disp(['Driver version: ', num2str(calllib('libljacklm','GetDriverVersion'))]);
            
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
        
        
    end % methods
    
    methods (Access = public)
        
        function out = afterFrame(self, currentTime, rewardState)
            
            self.frameCounter = self.frameCounter + 1;
        end 

        function startfile(self,~)
                 %Setting and reading directions and states
                trisD = hex2dec('00FF');  %Setting D0-7 to outputs, D8-15 to inputs (b0000000011111111)
                trisIO = hex2dec('3');  %Setting IO0-1 to outputs, IO2-3 to inputs (b0011)
                stateD = hex2dec('0001');  % 'eg : 00F0 sets D0-3 to low. D4-7 to high (b0000000011110000)
                stateIO = hex2dec('0');  %Setting IO0 to low. IO1 to low (b0010)
                updateDigital = 1;  %Updating D and IO lines
                outputD = 0;  %Returns of the output registers for D0-D15
                [errorCode, idnum, trisD, stateD, stateIO, outputD] = calllib('libljacklm','DigitalIO', self.idnum, self.demo, trisD, trisIO, stateD, stateIO, updateDigital, outputD);
                if(errorCode ~= 0)
                    calllib('libljacklm','GetErrorString',errorCode, errorString);
                    disp(['DigitalIO (update) error ' num2str(errorCode) ' : ' char(System.String(errorString))])
                    return
                end
        end    
           
        
        function init(self,~)
        end

        function readinput(self,~)
        end

        function starttrial(self,STARTCLOCK,STARTCLOCKTIME)
            %Generic 
%             % Set first bit high          
%             trisD = hex2dec('0001'); %bitmask
%             trisIO = 0;
%             stateD = hex2dec('0001'); 
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

            %Setting digital line IO0 to output-high
            channel = 0; %IO0
            writeD = 0; %Set IO line (>0 for D line)
            stateIO = 1; %Output-High (>0 = high, 0 = low)
            t(1)=GetSecs;
            [errorCode, idnum] = calllib('libljacklm','EDigitalOut', self.idnum, self.demo, channel, writeD, stateIO);
            %disp(['Setting digital line IO' num2str(channel) ' to output with state ' num2str(state)])
            if(errorCode ~= 0)
                calllib('libljacklm','GetErrorString', errorCode, errorString);
                disp(['EDigitalOut error ' num2str(errorCode) ' : ' char(System.String(errorString))])
                return
            end
            t(2)=GetSecs; 

        end

        function endtrial(self,ENDCLOCK,ENDCLOCKTIME)
%             % Set first bit high          
%             trisD = hex2dec('0001'); %bitmask?
%             trisIO = 0;
%             stateD = hex2dec('0000'); 
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

            %Setting digital line IO0 to output-low
            channel = 0; %IO0
            writeD = 0; %Set IO line (>0 for D line)
            stateIO = 0; %Output-High (>0 = high, 0 = low)
            t(1)=GetSecs;
            [errorCode, idnum] = calllib('libljacklm','EDigitalOut', self.idnum, self.demo, channel, writeD, stateIO);
            %disp(['Setting digital line IO' num2str(channel) ' to output with state ' num2str(state)])
            if(errorCode ~= 0)
                calllib('libljacklm','GetErrorString', errorCode, errorString);
                disp(['EDigitalOut error ' num2str(errorCode) ' : ' char(System.String(errorString))])
                return
            end
            t(2)=GetSecs; 

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
            %disp(['Setting digital line IO' num2str(channel) ' to output with state ' num2str(state)])
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
                stateD = hex2dec('0001');  % 'set d0 to 1, rest low eg : 00F0 sets D0-3 to low. D4-7 to high (b0000000011110000)
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
        
        function closefile(self)
            %Setting and reading directions and states
                trisD = hex2dec('00FF');  %Setting D0-7 to outputs, D8-15 to inputs (b0000000011111111)
                trisIO = hex2dec('3');  %Setting IO0-1 to outputs, IO2-3 to inputs (b0011)
                stateD = hex2dec('0000');  % 'eg : 00F0 sets D0-3 to low. D4-7 to high (b0000000011110000)
                stateIO = hex2dec('0');  %Setting IO0 to low. IO1 to low (b0010)
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
