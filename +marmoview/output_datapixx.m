classdef output_datapixx < marmoview.output
    % OUPUT_DATAPIXX is a class sending digital strobes with a datapixx
    % analog IO not implemented

    properties (SetAccess = private, GetAccess = public)
        
    end

    methods
        function obj = output_datapixx(varargin)
            %Usb2Serial Construct an instance of this class
            %
            if isempty(varargin)
                varargin = {'dummy', nan};
            end

            ip = inputParser();
            ip.KeepUnmatched = true;
            ip.parse(varargin{:});

            obj.init()

        end

        function init(~)
            if ~Datapixx('IsReady')
                Datapixx('Open');
            end

            % From help PsychDataPixx:
            % Timestamping is disabled by default (mode == 0), as it incurs a bit of
            % computational overhead to acquire and log timestamps, typically up to 2-3
            % msecs of extra time per 'Flip' command.
            % Buffer is collected at the end of the expeiment!
            PsychDataPixx('LogOnsetTimestamps',0);
            PsychDataPixx('ClearTimestampLog');

            %%% Open Datapixx and get ready for data aquisition %%%
            Datapixx('StopAllSchedules');
            Datapixx('DisableDinDebounce');
            Datapixx('EnableAdcFreeRunning');
            Datapixx('SetDinLog');
            Datapixx('StartDinLog');
            Datapixx('SetDoutValues',0);
            Datapixx('RegWrRd');
        end
    end

    methods (Access = public)
        function starttrial(obj,STARTCLOCK,STARTCLOCKTIME,~)
            % replace the datapixx strobe with a generic call to
            obj.strobe(63,0);  % send all bits on to mark trial start 

            for k = 1:6
                obj.strobe(STARTCLOCK(k),0);
            end
        end

        function endtrial(obj,ENDCLOCK,ENDCLOCKTIME,~)
            %******* the data pix strobe will take about 0.5 ms **********
            obj.strobe(62,0);% send all bits on but first (254) to mark trial end 

            %****** send the rest of the sixlet via DataPixx
           for k = 1:6
               obj.strobe(ENDCLOCK(k),0);
           end
        end

        function analogOut(~, open_time, chan, TTLamp)
            %datapixxanalogOut    Send a TTL pulse through the Analog Out
            % Send a [TTLamp] volt signal out the channel [chan], for [open_time] seconds
            %
            % Datapixx must be open for this function to work.
            %
            % INPUTS:
            %	      open_time - seconds to send signal (default = .5)
            %              chan - channel on datapixx to send signal
            %                     (you have to map your breakout board [3 on huk rigs])
            %            TTLamp - voltage (1 - 5 volts can be output) defaults to 3
            %
            %
            % written by Kyler Eastman 2011
            % modified by JLY 2012
            % modified by JK  2014

            if nargin < 3
                TTLamp = 3;
                if nargin < 2
                    chan = 3; % default reward channel on Huk lab rigs
                    if nargin < 1
                        open_time = .5;
                    end
                end
            end


            DOUTchannel = chan; % channel -- you have to map your breakout board

            sampleRate = 1000; % Hz MAGIC NUMBER??


            bufferData = [TTLamp*ones(1,round(open_time*sampleRate)) 0] ;
            maxFrames = length(bufferData);

            Datapixx('WriteDacBuffer', bufferData ,0 ,DOUTchannel);

            Datapixx('SetDacSchedule', 0, sampleRate, maxFrames ,DOUTchannel);
            Datapixx StartDacSchedule;
            Datapixx RegWrRd;
        end

        function timings=flipBit(obj,bit,trial)
            %pds.datapixx.flipBit    flip a bit on the digital out of the Datapixx
            %
            % pds.datapixx.flipBit flips a bit on the digital out of the Datapixx
            % box and back.
            %
            % NOTE: This code is optimized to use with the Plexon omniplex system.
            % We are using it it stobe only mode and thus simply forward the command to
            % pds.datapixx.stobe
            %
            % (c) jk 2015

            if nargout==0
                [~] = obj.strobe(trial,2^(bit-1));
            else
                timings=obj.strobe(trial,2^(bit-1));
            end
        end

        function flipBitVideoSync(~,bit)
            %pds.datapixx.flipBitVideoSync    flip a bit at the next VSync
            %
            % pds.datapixx.flipBit flips a bit on the digital out of the Datapixx
            % box, at the time the monitor refreshes the next time, but not back.
            %
            % NOTE: The Plexon system records only changes from 0 to 1, while the
            % Datapixx also records 1 to 0.
            %
            % (c) kme 2011

            Datapixx('SetDoutValues',2^16 + 2^(bit-1))
            Datapixx('RegWrRdVideoSync');
        end

        function timings=strobe(~,lowWord,highWord)
            % pds.datapixx.strobe    strobes a 16 Bit word from the datapixx
            %
            % pds.datapixx.strobe(lowWord,highWord)
            %
            % strobes two 8-bit words (255) from the datapixx
            % INPUTS
            %   lowWord            - bits 0-7 to strobe from Datapixx
            %   highWord           - bits 8-15 to strobe from Datapixx
            % OUTPUTS
            %   timings            - precise timing estimates of the time of the strobe
            %
            % requesting timings the output changes the methods of sending the stobe
            % and can negatively impact performance
            %
            % (c) kme 2011
            % jly 2013
            % jk 2015 changed to work with the plexon omiplex system

            if nargin < 2
                highWord=0;
            end
            
            word=mod(lowWord, 2^6) + mod(highWord,2^6)*2^6;
            
            if nargout==0
                %first we set the bits without the strobe, to ensure they are all
                %settled when we flip the strobe bit (plexon need all bits to be set
                %100ns before the strobe)
                Datapixx('SetDoutValues',word);
                Datapixx('RegWr');

                %now add the strobe signal. We could just set the strobe with a bitmask,
                %but computational requirements are the same (due to impememntation on
                %the Datapixx side)
                Datapixx('SetDoutValues',2^16 + word);
                Datapixx('RegWr');

                %Not required for plexon communication, but good practice: set to zero
                %again
                Datapixx('SetDoutValues',0,2^16)
                Datapixx('RegWr');
                Datapixx('SetDoutValues',0)
                Datapixx('RegWr');
            else
                t=nan(2,1);
                oldPriority=Priority;
                if oldPriority < MaxPriority('GetSecs')
                    Priority(MaxPriority('GetSecs'));
                end
                Datapixx('SetDoutValues',word);
                Datapixx('RegWr');

                Datapixx('SetDoutValues',2^16 + word);
                Datapixx('SetMarker');

                t(1)=GetSecs;
                Datapixx('RegWr');
                t(2)=GetSecs;

                Datapixx('SetDoutValues',0,2^16)
                Datapixx('RegWrRd');
                dpTime=Datapixx('GetMarker');

                Datapixx('SetDoutValues',0)
                Datapixx('RegWr');

                if Priority ~= oldPriority
                    Priority(oldPriority);
                end

                timings=[mean(t) dpTime diff(t)];
            end
        end


        function close(~)
            %close Datapixx at the end of an experiment.
            % this is really a barebones version until I can figure out everything
            % PLDAPS is using it to do, JM 10/7/2018

            % datapixx.close()
            %
            % datapixx.init is a function that turns off the DATAPIXX

            if Datapixx('IsReady')
                Datapixx('Close');
            end

        end

        function closefile(~)
        end


    end

end