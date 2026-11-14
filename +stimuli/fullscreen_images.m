classdef fullscreen_images < stimuli.stimulus % inherit stimulus to have tracking / random number generator
  % Matlab class for drawing an image (typically a face) in a Gauss window
  %
  % The class constructor can be called with file name that is a .mat of images
  %  and what is the background gray scale (for Gauss windowing of image)
  %
  %   bkgd  - background gray
  %   gray  - true if gray only, else full color
  %
  % 26-08-2018 - Jude Mitchell
  % 19-02-2026 - Declan Rowley, edits for full screen non-whitened images from folder. 
  % Copying logic from grating_driftings.m for GratOnDur and OffDur, but
  % there is for sure a better way to do this.

  % LEAVING THIS UNFINISHED, USING PR_BACKIMAGESET INSTEAD
  % THIS WOULD BE A USEFUL STARTING POINT FOR IMAGES FOR A FORAGE TASK 
  properties (Access = public)
    tex
    texDim
    imagenum double = 0   %if set zeros, picks at random which to show
    position double = [0.0, 0.0] % [x,y] (pixels)
    radius double = Inf  % size in pixels, must be set
    bkgd double = 127
    gray logical = true
    transparency double = 0
    durationOn double  % duration an image is on (frames)
    durationOff double % inter-stimulus interval (frames)
    isiJitter double % amount of jitter to add to the isi (frames)
    frameUpdate % counter for updating the frame
    currentImage % imagenumber relative to original ordered names: o.tex(imagenum)
  end
        
  properties (Access = public)
    winPtr % ptb window
  end
  
  methods (Access = public)
    function o = fullscreen_images(winPtr,varargin) % marmoview's initCmd?
      o.winPtr = winPtr;
      o.tex = [];
      o.texDim = [];
      
      if nargin == 1
        return
      end

      % initialise input parser
      args = varargin;
      p = inputParser;
      p.StructExpand = true;
      
      p.addParameter('position',o.position,@isfloat); % [x,y] (pixels)
      p.addParameter('radius',o.radius,@isfloat); % [x,y] (pixels)
      p.addParameter('gray',o.gray,@islogical);
      p.addParameter('bkgd',o.bkgd,@isfloat);
      p.addParameter('imagenum',o.imagenum,@isfloat);
      ip.addParameter('durationOn', 1)
      ip.addParameter('durationOff', 1)
      ip.addParameter('isiJitter', 0)
      p.addParameter('transparency',o.transparency,@isfloat);
                  
      try
        p.parse(args{:});
      catch
        warning('Failed to parse name-value arguments.');
        return;
      end
      
      args = p.Results;
    
      o.position = args.position;
      o.radius = args.radius;
      o.gray = args.gray;
      o.bkgd = args.bkgd;
      o.transparency = args.bkgd;
      o.frameUpdate = 0;
     
    end
    
    function o = loadimages(o,foldername)
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
             o.tex(ii) = Screen('MakeTexture',o.winPtr,o.imo{ii});
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

        
       % F = load(foldername);
       % images = fields(F);
       % n = length(images);
       % if o.winPtr==0
       %     o.tex = cell(n,1);
       % else
       %     o.tex = nan(n,1);
       % end
       % o.texDim = nan(n,1);
       % for i = 1:n
       %    imo = F.(images{i});
       %    o.texDim(i) = length(imo);  
       %    [x,y] = meshgrid((1:o.texDim(i))-o.texDim(i)/2);
       %    g = exp(-(x.^2+y.^2)/(2*(o.texDim(i)/6)^2));
       %    g = repmat(g,[1 1 3]);
       %    im = uint8((g.*double(imo)) + o.bkgd*(1-g));  % Should be 127 if gamma, 186 if not
       %    if (o.gray)
       %       im = uint8(squeeze(mean(im,3)));  % go to grayscale 
       %    end
       %    % o.tex(i) = Screen('MakeTexture',o.winPtr,im);
       % 
       %    % then define transparency for g-blending
       %    if (o.transparency > 0)
       %       t1 = 255 * (squeeze(mean(g,3)) > 0.05); 
       %    else
       %       t1 = 255 * squeeze(mean(g,3)); 
       %    end
       %    rim = uint8( zeros(size(im,1),size(im,2),4) );
       %    rim(:,:,1) = im(:,:,1);
       %    rim(:,:,2) = im(:,:,2);
       %    rim(:,:,3) = im(:,:,3);
       %    %**** set transparency
       %    rim(:,:,4) = uint8(t1);
       %    % Create the gauss texture 
       %    if o.winPtr ~= 0
       %      o.tex(i) = Screen('MakeTexture',o.winPtr,rim);
       %    else
       %      o.tex{i} = rim;
       %    end
       % 
       %    %**** initialize default radius based on last loaded image size
       %    o.radius = length(imo);
       % end        
    end
    
    function CloseUp(o)
       if ~isempty(o.tex)
          for i = 1:size(o.tex,1) 
            Screen('Close',o.tex(i)); 
          end
          o.tex = [];
       end
    end
        
    function beforeTrial(o)
        o.setRandomSeed(); % set the random seed
        o.frameUpdate = 0;
    end
    
    function beforeFrame(o)
      if (o.imagenum)
          o.drawGaussImage(o.imagenum);
      else
          rd = randi(o.rng, length(o.tex));  
          o.drawGaussImage(rd);
      end
    end
        
    function afterFrame(o)
        % frameUpdate can be 0, < 0 or > 0
        % frameUpdate = 0, select a new grating
        % frameUpdate > 0, draw grating and count down to 0
        % frameUpdate < 0, draw no grating and count up to 0
        if o.frameUpdate==0%, select a new image
            if o.stimValue==1 %stimuli was just on, set to blank
                jitter = round(rand(o.rng)*o.isiJitter);
                o.frameUpdate = -(o.durationOff + jitter); % new frame update is a negative number to indicate time off
                o.stimValue = 0; % turn stimulus off
            elseif o.stimValue==0 %stimuli was just blank, set to image
                o.currentImage=1;% TODO RANDOM CALL TO IMAGE BANK OR PREPREPED SEQUENCE
                jitter = round(rand(o.rng)*o.isiJitter);
                o.frameUpdate = (o.durationOn + jitter);
            end
        elseif o.frameUpdate > 0%, draw image and count down to 0
            drawGaussImage(o,o.currentImage)
            o.frameUpdate = o.frameUpdate -1;
        else % frameUpdate < 0 %, draw blanks and count up to 0
            Screen('FillRect',o.winPtr,o.bkgd) ;
            o.frameUpdate = o.frameUpdate +1;
        end
    end
    
    function drawGaussImage(o,imagenum)
       if ( (imagenum>0) && (imagenum <= size(o.tex,1)) ) 
         if (~isempty(o.tex(imagenum)))
             if o.radius<Inf
                 rect = kron([1,1],o.position) + kron(o.radius,[-1, -1, +1, +1]);
                 texrect = [0 0 o.texDim(imagenum) o.texDim(imagenum)];
                 Screen('DrawTexture',o.winPtr,o.tex(imagenum),texrect,rect,0);
             else
                 Screen('DrawTextures',o.winPtr,o.tex(imagenum),o.ImoRect,o.ScreenRect) 
             end
         end
       end
    end
    
    function varargout = getImage(o, rect, binsize)
        
        if o.winPtr~=0
            warning('gaussimages: getImage: only works if you constructed the object with winPtr=0')
        end
        
        if nargin < 3
            binsize = 1;
        end
        
        if nargin < 2
            rect = o.position([1 2 1 2]) + [-1 -1 1 1].*o.radius/2;
        end
        

        
        I = o.tex{o.imagenum};
        I = double(I);
        alpha = squeeze(I(:,:,4))./255;
        I(:,:,4) = [];
        for i = 1:3
            I(:,:,i) = I(:,:,i).*alpha + 127.*(1-alpha);
        end
        
        texrect = kron([1,1],o.position) + kron(o.radius,[-1, -1, +1, +1]);
        I = imresize(I, [texrect(4)-texrect(2) texrect(3)-texrect(1)]);
        alpha = imresize(alpha, [texrect(4)-texrect(2) texrect(3)-texrect(1)]);
        
        % -- try to be a little quicker
        Iscreen = o.bkgd * ones(1080,1920); % bad that screensize is hardcoded
        Iscreen(texrect(2):texrect(4)-1, texrect(1):texrect(3)-1) = mean(I(:,:,1:3),3);
        Ascreen = zeros(1080,1920);
        Ascreen(texrect(2):texrect(4)-1, texrect(1):texrect(3)-1) = alpha;
        
        tmprect = rect;
        tmprect(3) = rect(3)-rect(1)-1;
        tmprect(4) = rect(4)-rect(2)-1;
        
        
        im = imcrop(Iscreen, tmprect); % requires the imaging processing toolbox
        alpha = imcrop(Ascreen, tmprect);
        
        if binsize~=1
            im = im(1:binsize:end,1:binsize:end);
            alpha = alpha(1:binsize:end,1:binsize:end);
        end
        

        
        
%         % -- works, but you have to draw
%         texax = texrect(1):binsize:texrect(3);
%         texay = texrect(2):binsize:texrect(4);
%         
%         
%         figure(9999); clf
%         if binsize ~=1
%             I = imresize(I, 1./binsize);
%         end
%         imagesc(texax, texay, I)
%         xlim([rect(1) rect(3)])
%         ylim([rect(2) rect(4)])
%         
%         frame = getframe(gca);
%         im = frame.cdata;
%         %
        
        if nargout > 0
            varargout{1} = im;
        end
        
        if nargout > 1
            varargout{2} = alpha;
        end
        
    end
    
  end % methods
  
end % classdef
