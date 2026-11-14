classdef barcode < stimuli.stimulus % inherit stimulus to have tracking / random number generator
  % Matlab class for drawing a 1d noise stimuli (barcode) in a Gauss window
  %
  % The class constructor can be called with file name that is a .mat of images
  %  and what is the background gray scale (for Gauss windowing of image)
  %
  %   bkgd  - background gray
  %   gray  - true if gray only, else full color
  %
  %  Declan Rowley 2022, borrowing heavily from Jude Mitchell's gaussimages.m
  
  properties (Access = public)
    tex
    texDim
    saveline 
    savesquare
    position double = [0.0, 0.0] % [x,y] (pixels)
   
    
    bkgd double = 127
    gray logical = true
    transparency double = 0;%0.5
    prctgray double = 33.3   
    texnum double = 1

    radius double  % size in pixels, must be set
    barwidth double      
    prefori 
    pixPerDeg double
    updateEveryNFrames % if the update should only run every 
    Ntex double = 24000 %60*10*40
  end
        
  properties (Access = private)
    winPtr % ptb window
  end
  
  methods (Access = public)
    function o = barcode(winPtr,varargin) % marmoview's initCmd?
      o.winPtr = winPtr;
      o.tex = [];
      o.texDim = [];
      o.saveline = [];
      o.savesquare = [];
      
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
      p.addParameter('transparency',o.transparency,@isfloat);
      p.addParameter('prctgray',o.prctgray,@isfloat); % 
      p.addParameter('barwidth',o.barwidth,@isfloat); % 
      p.addParameter('texnum',o.texnum,@isfloat); % 
      p.addParameter('Ntex',o.Ntex,@isfloat); % 
      p.addParameter('prefori',o.prefori,@isfloat); % 
      
      p.addParameter('pixPerDeg', [])
      p.addParameter('updateEveryNFrames', 1)
                  
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
      o.prctgray = args.prctgray;
      o.barwidth = args.barwidth;
      o.texnum = args.texnum;
      o.Ntex = args.Ntex;
      o.prefori = args.prefori;
      
      if isempty(o.pixPerDeg)
            warning('barcode: I need the pixPerDeg to be accurate')
            o.pixPerDeg = 37.5048;
      end
      
    end
    
 
    function makeTex(o)
        %Initialise 1d stimulus
        barwidth_px = o.barwidth;
        diam_px     = o.radius*2; %actually using radius
        percntgray  = 100/o.prctgray;
        
        %Round up,
        pixperbar=ceil(barwidth_px);
        nbars=ceil(diam_px/barwidth_px);
        
        nTex=o.Ntex;
        line=zeros(nTex,nbars);
        square=zeros(nbars,nbars,nTex);
        
        %1D stimuli, [-1 0 1]
        for ii =1:nTex
            line(ii,:)=round((100/percntgray)*(rand(1,nbars) - .5));
            line(ii,line(ii,:)>0)= 1;
            line(ii,line(ii,:)<0)=-1;
            
            square(:,:,ii)= repmat(line(ii,:),nbars,1);
%             imagesc(square(:,:,ii))
%             pause(0.01)
        end
                
        % Transform the range to [0 127.5 255]
        line=o.bkgd*(line+1);
        square=o.bkgd*(square+1);
        
        %Center textures, and cut off edges
        % Imresize blurs, 
  %      square= imresize(square,pixperbar);%repmat(square,4)
        
        
        square1=repmat(square,1,1,1,pixperbar,pixperbar);
        square1 = permute(square1, [1 4 5 2 3]);
        square1=reshape(square1,[nbars*pixperbar nbars*pixperbar nTex]);
        square = square1;
        
        cropout= rem(size(square,1),diam_px);
        
        %This might not work great with odd numbers
        square=square((1+cropout/2):end-cropout/2,(1+cropout/2):end-cropout/2,:);
        
        % Save into o 
        o.saveline=line;
        o.savesquare=square;

        
        
        for i=1:nTex
            imo= square(:,:,i);
            o.texDim(i) = length(imo);
            [x,y] = meshgrid((1:o.texDim(i))-o.texDim(i)/2);
            g = exp(-(x.^2+y.^2)/(2*(o.texDim(i)/6)^2));
            
            im = uint8((g.*double(imo)) + o.bkgd*(1-g));  % Should be 127 if gamma, 186 if not

            % o.tex(i) = Screen('MakeTexture',o.winPtr,im);
            % then define transparency for g-blending
            if (o.transparency > 0)
                t1 = 255 * (squeeze(mean(g,3)) > 0.05);
            else
                t1 = 255 * squeeze(mean(g,3));
            end
          
            rim = uint8( zeros(size(im,1),size(im,2),4) );
            rim(:,:,1) = im;
            rim(:,:,2) = im;
            rim(:,:,3) = im;
            %**** set transparency
            rim(:,:,4) = uint8(t1);


            % Create the gauss texture 
            if o.winPtr ~= 0
            o.tex(i) = Screen('MakeTexture',o.winPtr,rim);
            else
            o.tex{i} = rim;
            end

            %**** initialize default radius based on last loaded image size
            o.radius = length(imo);
        end
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
    end
    
    function beforeFrame(o)
      if (o.texnum)
          o.drawGaussImage(o.texnum);
      else
          %Textures are already random, do we need to shuffle here?
          rd = randi(o.rng, o.Ntex);  
          o.drawGaussImage(rd);
      end
    end
        
    function afterFrame(o)
    end
    
    function drawGaussImage(o,texnum)
       if ( (texnum>0) && (texnum <= size(o.tex,2)) ) 
         if (~isempty(o.tex(texnum)))
           rect = kron([1,1],o.position) + kron(o.radius,[-1, -1, +1, +1]);
           texrect = [0 0 o.texDim(texnum) o.texDim(texnum)];
           ori = o.prefori;
           Screen('DrawTexture',o.winPtr,o.tex(texnum),texrect,rect,ori);
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
        

        
        I = o.tex{o.texnum};
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














