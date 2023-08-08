classdef output_sbx2p  < handle
    %VOG Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        t
        ip
        RemotePort
        LocalPort
        connected
    end

    properties (SetAccess = private, GetAccess = public)
        Starttime
        Stoptime
    end

    
    methods
        function o = output_sbx2p(~,varargin) 
            % initialise input parser
            p = inputParser;
           
            p.addParameter('ip','192.168.1.1') 
            p.addParameter('LocalPort',9090);     
            p.addParameter('RemotePort', 7000)
            

            p.parse(varargin{:});
            
            args = p.Results;
            
            o.ip=args.ip;
            o.LocalPort=args.LocalPort;
            o.RemotePort=args.RemotePort;
            
           
            %attempt to connect overUDP
            o.connected=o.Connect(o.ip,o.LocalPort,o.RemotePort);
            

        end

        function startfile(o,app)
            %app.outputPrefix;
           
            %app.outputSuffix;
            % full app.A.outputFile;
            
            A=['A' app.outputSubject];
            U=['U' app.outputDate '_' app.outputPrefix];
            E=['E' app.outputSuffix];

            o.sendcommand(A);
            o.sendcommand(U);
            o.sendcommand(E);

            o.StartRecording
            o.Starttime=GetSecs;
        end
        
        function closefile(o,app)
            o.StopRecording
            o.Stoptime=GetSecs;

            %Incrementing file name to stop from accidentally overwriting
            E=['E' num2str(str2num(app.outputSuffix)+1,'%.2d')];
            
            o.sendcommand(E);
        end
        
        function unpause(~,~)
        end
        
        function pause(~)
        end
        
        function starttrial(o,~,~)%(o,STARTCLOCK,STARTCLOCKTIME)
%             s='M Trial Start';  % Message 
%             fprintf(o.t,s);
        end

        function endtrial(o,~,~,~)
%             s='M Trial End';  % Message
%             fprintf(o.t,s);
        end

        function readinput(o,~)
        end
     
        function sendcommand(o,s)
            fprintf(o.t,s);
        end

        function drop= afterFrame(~, ~, rewardState)
            drop=rewardState; %passthrough
        end


        function result = Connect(o, ip, LocalPort, RemotePort)
            result = 0;
            o.t  = udp(ip, 'RemotePort', RemotePort,'LocalPort',LocalPort);
            fopen(o.t);


%             this.ip = ip;
%             this.port = LocalPort;
%             this.t = udpport("IPV4", "Timeout", 3);
%             
%             result = 1;
        end
        

        function close(o)
            if ( ~isempty( o.t) )
                s='S';  % Stop sampling (Go)
                fprintf(o.t,s);
            end
            %clear o.t
            fclose(o.t);
            o.t =[];
        end

        function StartRecording(o)
            if ( ~isempty( o.t) )
                s='G';  % start sampling (Go)
                fprintf(o.t,s);
            end
        end
        
        function StopRecording(o)
            if ( ~isempty( o.t) )
                s='S';  % Stop sampling (Go)
                fprintf(o.t,s);
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
%                 write(this.t,uint8('waitfordata'),"uint8",this.ip,this.port);
%                 write(this.t,uint8('getdata'),"uint8",this.ip,this.port);
%                 while(this.t.NumBytesAvailable == 0 )
%                     %This seems dangerous
%                 end
%                 bytes = read(this.t, this.t.NumBytesAvailable, "uint8");
%                 datastr = char(bytes);
%                 dataarray = str2double(string(strsplit(datastr,';')'));

            end
        end
    end
    
    methods(Static = true)
        
    end
    
end

