classdef PR_BackImageSet < handle
  % Matlab class for running an experimental protocl
  %
  % The class constructor can be called with a range of arguments:
  %
  properties (Access = public)
       Iti double = 4;        % default Iti duration
       startTime double = 0;  % trial start time
       imageOff double = 0;   % offset of image
  end
      
  properties (Access = private)
    winPtr; % ptb window
    state double = 0;      % state countern trial
    error double = 0;      % default, need defined even if always 0
   %************
    S;      % copy of Settings struct (loaded per trial start)
    P;      % copy of Params struct (loaded per trial)
    ImoScreen = [];    % image to display, full screen
    ImoRect = [];
    ScreenRect = [];
    ImageDirectory = [];  % directory from which to pull images
    ImageFile = [];
    imo = [];  % matlab image struct
    grayscale = false
    nImages= 108;
    tex=1;
    texlist=1:108;
    ImageHistory = [];
    MaxFrame=[];
    imagestart=[];
    %**** Photodiode flash timing
    FrameCount = 0;
    Flashtime = [];
    %**********************************
  end
  
  methods (Access = public)
    function o = PR_BackImageSet(winPtr)
      o.winPtr = winPtr;     
    end
    
    function state = get_state(o)
        state = o.state;
    end
    
    function initFunc(o,S,P)
        o.ImoScreen = [];
        o.ImageDirectory = S.ImageDirectory;
        if isfield(P, 'useGrayScale')
            o.grayscale = P.useGrayScale;
        end

        o.MaxFrame = ceil(220*S.frameRate); %108 seconds *2 +buffer
        o.ImageHistory = nan(o.MaxFrame,3);

        % Load up images once only, park them as textures on Graphics
        % memory rather than loading them per trial

         %********************
          o.S = S;
          o.P = P;       
          %*******************
          flist = dir([o.ImageDirectory,filesep,'*.*']);
          fext = cellfun(@(x) x(strfind(x, '.'):end), {flist.name}, 'uni', 0);
          %for files with blah.blahblah.png etc
          dotfiles=find(cellfun(@(x) contains(x(2:end),'.'), fext, 'uni', 1));
          for ii=1:length(dotfiles)
            fext{dotfiles(ii)}=fext{dotfiles(ii)}(strfind(fext{dotfiles(ii)}(2:end), '.')+1:end);
          end

          isimg = cellfun(@(x) any(strcmp(x, {'.bmp', '.png', '.jpg', '.jpeg', '.JPG', '.PNG'})), fext);
          flist = flist(isimg);

          o.closeFunc();  % clear any remaining images in memory
                          % before you allocated more (one per time)
          
          %Random draw from files
          for ii= 1:o.P.nImages
          %******************
          if (~isempty(flist))
              % We need to be careful about randomising here if we are also
              % going to randomise later
             fimo = ii;%1 + floor( (rand * 0.99) * size(flist,1) );
             fname = flist(fimo).name;  % name of an image
             o.ImageFile{ii} = [o.ImageDirectory,filesep,fname];
             o.imo{ii} = imread(o.ImageFile{ii});
             
             % image can't be bigger than screen. Don't waste texture size?
             [rows,cols,~]=size(o.imo{ii});
             if ~all([rows,cols]==S.screenRect([4 3]))
                 [asp,rc]=min([rows,cols]./S.screenRect([4 3]));
                 if rc==1 %crop cols
                    ncols=round(S.screenRect([3])*asp);
                    cut=(cols-ncols)/2;
                    o.imo{ii}=o.imo{ii}(:,cut:end-cut,:);
                 elseif rc==2 %crop rows
                    nrows=round(S.screenRect([4])*asp);
                    cut=(rows-nrows)/2;
                    o.imo{ii}=o.imo{ii}(cut:end-cut,:,:);
                 end
                 o.imo{ii} = imresize(o.imo{ii}, S.screenRect([4 3]));
             end

             if o.grayscale
                 o.imo{ii} = uint8(mean(o.imo{ii},3));
             end
             %******* insert image in middle texture
             o.ImoScreen(ii) = Screen('MakeTexture',o.winPtr,o.imo{ii});
             o.ImoRect = [0 0 size(o.imo{ii},2) size(o.imo{ii},1)];
             o.ScreenRect = S.screenRect;
          end
          end

          aspectRatio = size(o.imo{1},1)./size(o.imo{1},2);
          
          % check if there are size and position variables
          if isfield(P, 'imageSizes') && isfield(P, 'imageCtrX') && isfield(P, 'imageCtrY')
              imWidthDeg = randsample(P.imageSizes, 1);
              imWidthPx = S.pixPerDeg * imWidthDeg;
              imHeightPx = aspectRatio * imWidthPx;
              
              ctr = S.centerPix + [P.imageCtrX P.imageCtrY]*S.pixPerDeg;
              o.ScreenRect = CenterRectOnPoint([0 0 imWidthPx imHeightPx], ctr(1), ctr(2));
          end
    end
   
    function load_image_dir(o,imagedir)
        o.ImageDirectory = imagedir;
    end
    
    function closeFunc(o)
        if (~isempty(o.ImoScreen))
            Screen('Close',o.ImoScreen);
            o.ImoScreen = [];
        end
        if (~isempty(o.imo))
            clear o.imo;
            o.imo = [];
        end     
    end
   
    function generate_trialsList(o,S,P) %#ok<*INUSD>
           % nothing for this protocol

           % This should randomize the order of image textures if not done
           % in next_trial()
           
    end
    
    function P = next_trial(o,S,P)
         o.texlist = randperm(o.P.nImages);
          o.FrameCount = 0;
          o.Flashtime = [];
    end
    
    function [FP,TS] = prep_run_trial(o)
        % Setup the state
        o.state = 0; % Showing the face
%         Iti = o.P.iti;   % set ITI interval from P struct stored in trial
        %*******
        FP(1).states = 0;  % any special plotting of states, 
        FP(1).col = 'b';   % FP(1).states = 1:2; FP(1).col = 'b';
                           % would show states 1,2 in blue for eye trace
        %******* set which states are TimeSensitive, if [] then none
        TS = [];  % no sensitive states in FaceCal
        %********
        o.startTime = GetSecs;

    end
    
    function keepgoing = continue_run_trial(o,screenTime)
        keepgoing = 0;
        if (o.state < 4)
            keepgoing = 1;
        end
        %******** this is also called post-screen flip, and thus
        %******** can be used to time-stamp any previous graphics calls
        %******** for object on the screen and things like that
        if (o.FrameCount)
           o.ImageHistory(o.FrameCount,1) = screenTime;  %store screen flip 
        end

    end
   
    %******************** THIS IS THE BIG FUNCTION *************
    function drop = state_and_screen_update(o,currentTime,x,y, varargin)
         outputs = {};
         if ~isempty(varargin)
             inputs=varargin{1};
             if length(varargin)>1
                outputs=varargin{2};
             end
         end 
        drop = 0;

        %******* THIS PART CHANGES WITH EACH PROTOCOL ****************
        if currentTime > o.startTime + o.P.trialDur
            o.state = 4; % Inter trial interval
            o.imageOff = GetSecs;
            drop = 1; 
            %return
        end

        % New states: 0 is nothing, 1 is stimuli on, 2 is isi, 4 is iti,
        if o.state==0 %new trial, start on first image (relative to list) 
            o.imagestart = currentTime;
            o.tex=1;
            o.state=1;
        end

        % Transition into isi
        if o.state ==1 && (currentTime) > (o.imagestart + o.P.imageDur)% Update stimuli
            o.imagestart=currentTime;
            o.state=2;
        end

        % Transition out of isi
        if o.state ==2 && (currentTime) > (o.imagestart+ o.P.isiDur)% Update stimuli
            o.tex = o.tex+1;
            o.tex=rem(o.tex-1,o.P.nImages)+1; %restart sequence if not enough images
            o.imagestart=currentTime;
            o.state=1;
        end


%            case 1
        %disp(o.state)
        if o.state==1 %images
            if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                Screen('DrawTextures',o.winPtr,o.ImoScreen(o.texlist(o.tex)),o.ImoRect,o.ScreenRect)  % draw
                Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                Screen('DrawTextures',o.winPtr,o.ImoScreen(o.texlist(o.tex)),o.ImoRect,o.ScreenRect)  % draw
            else
                Screen('DrawTextures',o.winPtr,o.ImoScreen(o.texlist(o.tex)),o.ImoRect,o.ScreenRect)        
            end
        elseif o.state ==2 %Isi
            if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                Screen('FillRect',o.winPtr,o.S.bgColour);  % draw
                Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                Screen('FillRect',o.winPtr,o.S.bgColour);  % draw
            else
                Screen('FillRect',o.winPtr,o.S.bgColour);       
            end
        end
        
        %Save image index relative to filelist
        o.FrameCount = o.FrameCount + 1;
        o.ImageHistory(o.FrameCount,2)=o.texlist(o.tex); 

%         end 
        %**************************************************************



        o.Flashtime = marmoview.updatePhotodiode(o.winPtr,o.S,outputs,o.FrameCount,currentTime,o.Flashtime);


    end
    
    function Iti = end_run_trial(o)
        Iti = o.Iti;  % returns generic Iti interval (not task dep)
    end
    
    function plot_trace(o,handles)
        %***** nothing to append, just plot the basic trace
        %***** but scale and show the images inside eyetrace panel
        eyeRad = handles.eyeTraceRadius;
        %***********
        dx = size(o.imo{1},2)/(o.ScreenRect(3)-o.ScreenRect(1));
        dy = size(o.imo{1},1)/(o.ScreenRect(4)-o.ScreenRect(2));
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
        cp = [floor(size(o.imo{1},2)/2), floor(size(o.imo{1},1)/2)];
        idx = floor( dp * dx );
        idy = floor( dp * dy );
        ix = ceil(cp(1)-idx):floor(cp(1)+idx);
        iy = ceil(cp(2)-idy):floor(cp(2)+idy);
        %****** rescale for imagesc command
        cix = (ix - cp(1)) * (eR/idx);
        ciy = (iy - cp(2)) * (eR/idy);
        %*********** draw the scaled image, then overlay eye position
        subplot(handles.EyeTrace); hold off;
%         H = imagesc(cix,ciy,flipud(o.imo(iy,ix,:)));
        imagesc(cix,ciy,flipud(o.imo{1}(iy,ix,:))); % don't output handle
        if (size(o.imo{1},3)==1)
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
        PR.destRect = o.ScreenRect;
        PR.lastimg = o.tex;
        PR.texlist = o.texlist;
        PR.ImageHistory = o.ImageHistory;
        PR.Flashtime = o.Flashtime;
    end
    
  end % methods
    
end % classdef
