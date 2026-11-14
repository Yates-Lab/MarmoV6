classdef PR_BackVideoXLB < handle
  % Matlab class for running an experimental protocl
  %
  % The class constructor can be called with a range of arguments:
  %
  
  properties (Access = public),    
       Iti@double = 1;        % default Iti duration
       startTime@double = 0;  % trial start time
       imageOff@double = 0;   % offset of image
       videostartTime@double = 0; % start of playing video
       videoendTime@double = 0;
       JuiceTimer = 0;
  end
      
  properties (Access = private)
    winPtr; % ptb window
    state@double = 0;      % state countern trial
    error@double = 0;      % default, need defined even if always 0
   %************
    S;      % copy of Settings struct (loaded per trial start)
    P;      % copy of Params struct (loaded per trial)
    ImoScreen = [];    % image to display, full screen
    vidObj = [];       % VideoReader object
    ImoMaxN = 1200;     % max number of video frames stored into textures
    ImoCount = 1;
    ImoRect = [];
    ScreenRect = [];
    ImageRect = [];
    ImageScreenRect = [];
    ImageDirectory = [];  % directory from which to pull images
    ImageFile = [];
    VideoDirectory = [];  % directory from which to pull images
    VideoFile = [];
    VideoScreen = [];
    imo = [];  % matlab image struct
    imostill = []; % static image struct for background
    VidCounts = [];  % time-stamps for texture commands
    %********
    Ilist = [];
    Inum = 0;
    Iperm = [];
    Icount = 0;
    %*******
    Vlist = [];
    Vnum = 0;
    Vperm = [];
    Vcount = 0;
    %********
  end
  
  methods (Access = public)
    function o = PR_BackVideoXLB(winPtr)
      o.winPtr = winPtr;     
    end
    
    function state = get_state(o)
        state = o.state;
    end
    
    function initFunc(o,S,P);
        o.ImoScreen = [];
        o.ImageDirectory = S.ImageDirectory; 
        o.VideoDirectory = S.VideoDirectory;
        %*************
        o.Ilist = dir([o.ImageDirectory,filesep,'*.jpeg']);
        o.Vlist = dir([o.VideoDirectory,filesep,'*.avi']);
        o.Inum = length(o.Ilist);
        o.Vnum = length(o.Vlist);
        o.Iperm = randperm(o.Inum);
        o.Vperm = randperm(o.Vnum);
        o.Icount = 1;
        o.Vcount = 1;
        %***************
    end
   
    function load_image_dir(o,imagedir)
        o.ImageDirectory = imagedir;
    end
    
    function closeFunc(o),
        o.closeImage();
    end
   
    function closeImage(o)
        if (~isempty(o.ImoScreen)) && (o.ImoScreen > 0)
              Screen('Close',o.ImoScreen);
              o.ImoScreen = [];
        end         
    end
    
    function generate_trialsList(o,S,P)
           % nothing for this protocol
    end
    
    function P = next_trial(o,S,P)  % draws trials in permuted order
          %********************
          o.S = S;
          o.P = P;       
          %*******************
          %******************
          if (~isempty(o.Ilist))
             fname = o.Ilist(o.Iperm(o.Icount)).name;  % name of image
             o.Icount = o.Icount + 1;
             if (o.Icount > o.Inum)
                 o.Icount = 1;
             end
             %******
             o.ImageFile = [o.ImageDirectory,filesep,fname];
             o.imostill = imread(o.ImageFile);
             %******* insert image in middle texture
             o.ImoScreen = Screen('MakeTexture',o.winPtr,o.imostill);
             o.ImageRect = [0 0 size(o.imostill,2) size(o.imostill,1)];
             o.ImageScreenRect = S.screenRect;
             o.ScreenRect = S.screenRect;   
          end
          %*********
          if (~isempty(o.Vlist))
             fname = o.Vlist(o.Vperm(o.Vcount)).name;  % name of image
             o.Vcount = o.Vcount + 1;
             if (o.Vcount > o.Vnum)
                 o.Vcount = 1;
             end
             o.VideoFile = fname;
             fullname = [pwd,filesep,o.VideoDirectory,filesep,fname];
             disp(['Reading file ',fullname]);
             o.vidObj = VideoReader(fullname); 
             o.vidObj
             o.VideoScreen = 0;             
          end    
          %********************
          o.ImoCount = 0;  % start with static natural image and use timer
    end

    function [FP,TS] = prep_run_trial(o)
        % Setup the state
        o.state = 0; % Showing the face
        o.ImoCount = 0;  % start video at beginning
        Iti = o.P.iti;   % set ITI interval from P struct stored in trial
        %*******
        FP(1).states = 0;  % any special plotting of states, 
        FP(1).col = 'b';   % FP(1).states = 1:2; FP(1).col = 'b';
                           % would show states 1,2 in blue for eye trace
        %******* set which states are TimeSensitive, if [] then none
        TS = [];  % no sensitive states in FaceCal
        %********
        o.VidCounts = [];  % list of frames and times shown
        o.startTime = GetSecs;
        o.JuiceTimer = GetSecs;
    end
    
    function keepgoing = continue_run_trial(o,screenTime)
        keepgoing = 1;
        if (o.ImoCount == o.ImoMaxN)
            keepgoing = 0;  % stop trial
        end
    end
   
    %******************** THIS IS THE BIG FUNCTION *************
    function drop = state_and_screen_update(o,currentTime,x,y) 
        drop = 0;
        %****** STOP IMAGE AND MOVE TO MOVIE 
        if (o.state == 0) && (o.ImoCount == 0)
            if (currentTime > o.startTime + o.P.imageDur)
                o.ImoCount = 1;
                o.videostartTime = GetSecs;
                o.imageOff = GetSecs;
                %drop = 1;  % drop of juice after image
                o.closeImage();  % clear back image from memory
            end
        end
        if (o.state == 0) && (o.ImoCount == o.ImoMaxN)
            o.videoendTime = GetSecs;
            %drop = 1;
        end
        
        if (currentTime > o.JuiceTimer + o.P.juiceInterval)
            o.JuiceTimer = currentTime;
            drop = 1;
        end
        
        %********** DRAWING COMMANDS
        if (o.ImoCount == 0)  % first frame shown, now load the rest ...!
            Screen('DrawTextures',o.winPtr,o.ImoScreen,o.ImageRect,o.ImageScreenRect);
        else
            if (o.VideoScreen > 0)  % clear texture as you go to not run out of memory
               Screen('Close',o.VideoScreen);
            end
            if hasFrame(o.vidObj)
               o.imo = readFrame(o.vidObj);
               o.ImoRect = [0 0 size(o.imo,2) size(o.imo,1)];
               o.VideoScreen = Screen('MakeTexture',o.winPtr,o.imo);
               % Screen('DrawTexture', o.winPtr, o.imo, [], o.ImoRect);
               Screen('DrawTextures',o.winPtr,o.VideoScreen,o.ImoRect,o.ScreenRect);
               %********
               o.VidCounts(o.ImoCount) = GetSecs();
               o.ImoCount = o.ImoCount + 1;
               if (o.ImoCount >= o.ImoMaxN)
                    %drop = 1;
                    o.videoendTime = GetSecs;
                    o.ImoCount = o.ImoMaxN;
               end
               %********
            else
               o.ImoCount = o.ImoMaxN;
            end
            %*********
        end
        %**************************************************************
    end
    
    function Iti = end_run_trial(o)
        Iti = o.Iti;  % returns generic Iti interval (not task dep)
    end
    
    function plot_trace(o,handles)
        %***** nothing to append, just plot the basic trace
        %***** but scale and show the images inside eyetrace panel
        eyeRad = handles.eyeTraceRadius;
        %***********
        dx = size(o.imostill,2)/(o.ScreenRect(3)-o.ScreenRect(1));
        dy = size(o.imostill,1)/(o.ScreenRect(4)-o.ScreenRect(2));
        %******* desired screen pixels to replicate
        dp = o.S.pixPerDeg * eyeRad;
        smax = floor(min((o.ScreenRect(4) - o.ScreenRect(2)),...
                         (o.ScreenRect(3) - o.ScreenRect(1)))/2);
        if (dp >= smax)
            eR = eyeRad * ((smax-1) / dp);   
            dp = (smax-1);
        else
            eR = eyeRad;
        end        
        %******* covert to actual image pixels (not identical to screen)
        cp = [floor(size(o.imostill,2)/2), floor(size(o.imostill,1)/2)];
        idx = floor( dp * dx );
        idy = floor( dp * dy );
        ix = ceil(cp(1)-idx):floor(cp(1)+idx);
        iy = ceil(cp(2)-idy):floor(cp(2)+idy);
        %****** rescale for imagesc command
        cix = (ix - cp(1)) * (eR/idx);
        ciy = (iy - cp(2)) * (eR/idy);
        %*********** draw the scaled image, then overlay eye position
        subplot(handles.EyeTrace); hold off;
        H = imagesc(cix,ciy,flipud(o.imostill(iy,ix,:)));
        if (size(o.imo,3)==1)
            colormap('gray');
        end
        HH = gcf;
        z = get(HH,'CurrentAxes');
        set(z,'YDir','normal');
    end
    
    function PR = end_plots(o,P,A)   %update D struct if passing back info     
        % Note, not passing in any complex information here
        PR = struct;
        PR.error = o.error;
        PR.startTime = o.startTime;
        PR.imageOff = o.imageOff;
        PR.imagefile = o.ImageFile;   % file name, if you want to load later
        PR.videofile = o.VideoFile;
        PR.videostartTime = o.videostartTime;
        PR.videoendTime = o.videoendTime;
        PR.videocounts = o.VidCounts;
    end
    
  end % methods
    
end % classdef
