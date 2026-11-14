classdef eyetrack_OpenIris  < handle
    %VOG Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        EyeDump logical
        UseAsEyeTracker logical
        t
        ip
        port
        connected
        eyesize = 0
    end

    properties (SetAccess = private, GetAccess = public)
        Eyedata
        Starttime
        Stoptime
    end

    
    methods
        function o = eyetrack_OpenIris(~,varargin) 
            % initialise input parser
            p = inputParser;
            p.addParameter('EyeDump',true,@islogical); % default 1, do EyeDump
            p.addParameter('ip',"100.1.1.1")
            p.addParameter('port',9003)
            p.addParameter('UseAsEyeTracker',1)
            p.parse(varargin{:});
            
            args = p.Results;
            o.EyeDump = args.EyeDump;
            o.ip=args.ip;
            o.port=args.port;
            o.UseAsEyeTracker=args.UseAsEyeTracker;
            %attempt to connect overUDP
            o.connected=o.Connect(o.ip,o.port);
            

        end

        function startfile(o)
            %o.SetSessionName(sessionName)
            o.StartRecording
            o.Starttime=GetSecs;
        end
        
        function closefile(o)
            o.StopRecording
            o.Stoptime=GetSecs;
        end
        
        function unpause(~,~)
        end
        
        function pause(~)
        end
        
        function starttrial(~,~,~)%(o,STARTCLOCK,STARTCLOCKTIME)
        end

        function endtrial(~,~,~,~)
        end

        function readinput(o,~)
            % Would love to append Eyedata into a stored matrix, but maybe
            % this isn't the place to do it. Reallocation will be key
%             if isempty(o.Eyedata)
                o.Eyedata=o.GetCurrentData;
%             else
%                 o.Eyedata=[o.Eyedata; o.GetCurrentData];
%             end
        end

        function [x,y] = getgaze(o,~)
            x=o.Eyedata(end).RightX;
            y=o.Eyedata(end).RightY;
        end
        
        function r = getpupil(o,~)
            r = o.Eyedata(end).RightPupilArea;
            %r = 1;
        end

        function C=calibinit(~,~)
            %Default to passthrough?
%             C.dx=1;
%             C.dy=1;
%             C.c=[.01 .01];
            
            %Gain
            C.dx=.18;
            C.dy=-.2;
            %Offset after gain?
            C.c=[.18 -.2]; 
        end
        
        function sendcommand(~,~,~)
        end

        function drop= afterFrame(~, ~, rewardState)
            drop=rewardState; %passthrough
        end


        function result = Connect(this, ip, port)
           result = 0;
           
            if ( ~exist('port','var') || isempty(port) )
                port = 9003;
            end
            
            this.ip = ip;
            this.port = port;
            this.t = udpport("IPV4","Timeout",0.4);
            
            result = 1;
        end
        

        function close(this)
            %clear this.t
            this.t =[];
        end
%         function result = IsRecording(this)
%             status = this.eyeTracker.Status;
%             result = status.Recording;
%         end
%         
%         function SetSessionName(this, sessionName)
%             if ( ~isempty( this.t) )
%                 this.t.ChangeSetting('SessionName',sessionName);
%             end
%         end
        
        function StartRecording(this)
            if ( ~isempty( this.t) )
                write(this.t,uint8('StartRecording'),"uint8",this.ip,this.port);
            end
        end
        
        function StopRecording(this)
            if ( ~isempty( this.t) )
                write(this.t,uint8('StopRecording'),"uint8",this.ip,this.port);
            end
        end
        
%         function frameNumber = RecordEvent(this, message)
%             frameNumber = [];
%             if ( ~isempty( this.eyeTracker) )
%                 frameNumber = this.eyeTracker.RecordEvent([num2str(GetSecs) ' ' message]);
%                 frameNumber = double(frameNumber);
%             end
%         end
        
        function data = GetCurrentData(this, message)


            if ( ~isempty( this.t) )
                % write(this.t,uint8('waitfordata'),"uint8",this.ip,this.port);
                write(this.t,uint8('getdata'),"uint8",this.ip,this.port);
                while(this.t.NumBytesAvailable == 0 )
                end
                bytes = read(this.t, this.t.NumBytesAvailable, "uint8");
                datastr = char(bytes);
                
                dataarray = str2double(string(strsplit(datastr,';')'));
                if length(dataarray)>1
                    %old version
                    data.LeftFrameNumber = dataarray(1);
                    data.LeftTime = dataarray(2);
                    data.LeftX = dataarray(3);
                    data.LeftY = dataarray(4);
                    data.RightFramenumber = dataarray(5);
                    data.RightTime = dataarray(6);
                    data.RightX = dataarray(7);
                    data.RightY = dataarray(8);
                else
                    %DPI
                    dataarray=jsondecode(datastr);
                    if isfield(dataarray,'Left')
                        data.LeftFrameNumber = dataarray.Left.FrameNumber;
                        data.LeftTime = dataarray.Left.Seconds;

                        data.LeftPupilWidth=dataarray.Left.Pupil.Size.Width;
                        data.LeftPupilHeight=dataarray.Left.Pupil.Size.Height;
                        data.LeftPupilArea=pi*(data.LeftPupilWidth/2)*(data.LeftPupilHeight/2);


                        if length(dataarray.Left.CRs)>3 %go for DPI
                            data.LeftX = dataarray.Left.CRs(4).X-dataarray.Left.CRs(1).X;%p4-p1
                            data.LeftY = dataarray.Left.CRs(4).Y-dataarray.Left.CRs(1).Y;
                        else %revert to pupil
                            data.LeftX = dataarray.Left.Pupil.Center.X;
                            data.LeftY = dataarray.Left.Pupil.Center.Y;
                        end
                    end
                    if isfield(dataarray,'Right')
                        data.RightFrameNumber = dataarray.Right.FrameNumber;
                        data.RightTime = dataarray.Right.Seconds;

                        data.RightPupilWidth=dataarray.Right.Pupil.Size.Width;
                        data.RightPupilHeight=dataarray.Right.Pupil.Size.Height;
                        data.RightPupilArea=pi*(data.RightPupilWidth/2)*(data.RightPupilHeight/2);

                        if length(dataarray.Right.CRs)>3 %go for DPI
                            data.RightX = dataarray.Right.CRs(4).X-dataarray.Right.CRs(1).X;%p4-p1
                            data.RightY = dataarray.Right.CRs(4).Y-dataarray.Right.CRs(1).Y;
                        else %revert to pupil
                            data.RightX = dataarray.Right.Pupil.Center.X;
                            data.RightY = dataarray.Right.Pupil.Center.Y;
                        end
                    end
                end
            end
        end

%         
%         
%         function [files]= DownloadFile(this, path)
%             files = [];
%             if ( ~isempty( this.eyeTracker) )
%                 try
%                     files = this.eyeTracker.DownloadFile();
%                 catch ex
%                     ex
%                 end
%                 files = cell(files.ToArray)';
%             end
%         end
    end
    
    methods(Static = true)
        
    end
    
end

