classdef ringwedges < stimuli.stimulus % inherit stimulus to have tracking / random number generator
  % Matlab class for drawing a RF mapping stimulus for intrinsic imaging,
  % wedges, rings and ring segments
  %
  % The class constructor can be called with file name that is a .mat of images
  %  and what is the background gray scale (for Gauss windowing of image)
  %
  %   bkgd  - background gray
  %   gray  - true if gray only, else full color
  %
  %  Declan Rowley 2024, borrowing heavily from barrf which was edited from
  %  Jude Mitchell's gaussimages.m
  %This is just set up for wedges as a quick retinotopic mapping tool for
  %intrinsic imaging. Some of the features here are not implemented but
  %were copied from previous implementation in PLADAPS
  
  properties (Access = public)
    tex
    filt
    texDim
    saveline 
    %savesquare
    position double = [0.0, 0.0] % [x,y] (pixels)
   
    isi
    bkgd double = 127
    gray logical = true
    contrast double = 1;%0.5 
    sparsity double = 1 
    texnum double = 1
    orinum double = 1

    pxradius double  % size in pixels, must be set
    barwidth double      
    prefori 
    pixPerDeg double
    updateEveryNFrames % if the update should only run every 
    Ntex double = (120*20);% Max runtime, 20s, 120fps
   
    stimCtr
    srcRect
    destRect
    pos
    
    
    period
    tf
    motionSteps 
    nRad
    nCycles
    fixSize %remove
    junkFrames %remove

    minphase
    maxphase
    phase %for wedges this is the polar angle of the center
    nphases % need to implement

    stim %stim type
    
    %Bar - untested
    nBar
    barWidth
    %Fullfield - untested
    meriThick
    meriStart
    %Ring - untested
    ringWidth

    %Wedges
    wedgeWidth
    nAng
    innerRad % in degrees
    %stimSize %might be used for something, try to remove
    startPhase double = 0
    
    displayctr
  end
        
  properties (Access = private)
    winPtr % ptb window
  end
  
  methods (Access = public)
    function o = ringwedges(winPtr,varargin) % marmoview's initCmd?
      o.winPtr = winPtr;
      o.tex = [];
      o.filt =[];
      o.texDim = [];
      o.saveline = [];
      %o.savesquare = [];
      
      if nargin == 1
        return
      end

      % initialise input parser
      args = varargin;
      p = inputParser;
      p.StructExpand = true;
      
      % Required inputs and defaults
      p.addParameter('position',o.position,@isfloat); % [x,y] (pixels)
      p.addParameter('pxradius',o.pxradius,@isfloat); % [x,y] (pixels)
      p.addParameter('gray',o.gray,@islogical);
      p.addParameter('bkgd',o.bkgd,@isfloat);
      p.addParameter('contrast',o.contrast,@isfloat);
      p.addParameter('sparsity',o.sparsity,@isfloat); % 
      p.addParameter('barwidth',o.barwidth,@isfloat); % 
      p.addParameter('texnum',o.texnum,@isfloat); % 
      p.addParameter('Ntex',o.Ntex,@isfloat); % 
      p.addParameter('prefori',o.prefori,@isfloat); % 

      p.addParameter('startPhase',o.startPhase,@isfloat); % 
      
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
      o.pxradius = args.pxradius;
      o.gray = args.gray;
      o.bkgd = args.bkgd;
      o.contrast = args.contrast;

      o.sparsity = args.sparsity;
      o.barwidth = args.barwidth;
      o.texnum = args.texnum;
%       o.Ntex = args.Ntex;
      o.prefori = args.prefori;
      
%        o.P.fixRadius      = o.P.Radius;
%        o.P.faceradius     = o.P.Radius;
%        o.P.proberadius    = o.P.Radius;
%       
      
      if isempty(o.pixPerDeg)
            warning('o.pixPerDeg is empty!!: I need the pixPerDeg to be accurate')
            o.pixPerDeg = 37.5048;
      end
      
    end
    
 
    function makeTex(o)
        %From BarRF
        diam_px     = o.pxradius*2; %actually using radius
               
        % From PLDAPS, switch out p.trial.(sn) for o
        % Making polar coords    
        %make cartesian matries
            [xx, yy] = meshgrid( linspace(-1, 1, diam_px), ...
                linspace(-1, 1, diam_px) );
        
            % srcRect is a apropriately sized rectangle for  
            o.srcRect = [0 0 size(xx,2)-1 size(xx,1)-1];
            
            stimCtr = o.stimCtr(:);% + o.stimOffset(:);
            
            for i = 1:2 % [x,y]
                o.pos(i,:) = (stimCtr(i));
            end
            o.pos = o.pos  .* o.pixPerDeg + o.displayctr(:,1:2)'; %now in pixels
           
            % destRect for texture, this will be in px coords
            o.destRect = CenterRectOnPoint(o.srcRect,o.pos(1,:)', o.pos(2,:)');
        
            %polar angle matrices
            [a,r] = cart2pol(xx,yy); %-pi to pi
            a(a<0)=a(a<0)+2*pi; %0 to 2*pi

            switch o.stim
                case {'bar', 'full-field'}
                    newX = xx * cos(0) - yy * sin(0); % Initial drifting bar is horizontal top to bottom!!!!
                    newY = xx * sin(0) + yy * cos(0);
                    wedges = sign(2*round((sin(2*o.nBar*pi*newX)+1)/2)-1);
                otherwise
                    %wedges = sign(2*round((sin(2*o.nAng*pi*a)+1)/2)-1);
%                     wedges = sign(round((sin(2*o.nAng*a)+1)/2)-1);
                    wedges = sign(round((sin(2*o.nAng*a)+1)/2)-0.5);
            end
            rings = zeros(size(wedges));
            posWedges = find(wedges == 1);
            negWedges = find(wedges == -1);
        
            % rings = sign(2*round((sin(o.nRad*pi*r)+1)/2)-1);
        
            % Make the checkerboard pattern on the wedges
            radCheck   = zeros(size(rings,1),size(rings,2),o.motionSteps);
            for i=1:o.motionSteps
                switch o.stim
                    case {'bar', 'full-field'}
                        tmprings1 = sign(2*round((sin(2*o.nBar*pi*newY + (i-1)/o.motionSteps*pi*2)+1)/2)-1);
                        tmprings2 = sign(2*round((sin(2*o.nBar*pi*newY - (i-1)/o.motionSteps*pi*2)+1)/2)-1);
                    otherwise
                        tmprings1 = sign(2*round((sin(2*o.nRad*pi*r + (i-1)/o.motionSteps*pi*2)+1)/2)-1);
                        tmprings2 = sign(2*round((sin(2*o.nRad*pi*r - (i-1)/o.motionSteps*pi*2)+1)/2)-1);
                end
                rings(posWedges)=tmprings1(posWedges);
                rings(negWedges)=tmprings2(negWedges);
        
                radCheck(:,:,i)= sign(wedges.*rings);
            end    
        
            %figure, imagesc(radCheck(:,:,1));
        
            str = sprintf('making %s textures', o.stim);
            % h = waitbar(0,str);
            fprintf('\n\n%s', str);
        
            toggle = -1; 
            o.Ntex=o.period*o.tf*2;
            textureIndex=nan(1,o.Ntex);
            switch o.stim
                case 'bar'
                    xLo = -1;
                    for i= 1:o.Ntex
                        %             flipTime=i/(o.tf*2);
                        xInc = (2-o.barWidth/o.nBar)/(o.Ntex);
                        %                 phase = (rem(flipTime+ o.startPhase*o.period,o.period)/o.period);%each cycle goes from 0 to 1
                        img = radCheck(:,:,mod(i-1,o.motionSteps)+1); %reset your image to the basic polar checkerboard each time
        
                        %determine where the ring should be
                        xLo = xLo + xInc;
                        xHi = xLo + o.barWidth/o.nBar;
        
                        %Zero out the areas of the image that you want grey
                        img(yy<xLo) = 0;
                        img(yy>xHi) = 0;
        
                        img(r<.04)=0;
                        img(r>1) = 0;
        
                        %make and draw your texture
                        textureIndex(i)=Screen('MakeTexture', o.winPtr, (img+1)*127.5);
            %             waitbar(i/(o.Ntex), h);
                        if ~mod(i,10)
                            fprintf('.');
                        end
                    end
                case 'full-field'
                    %o.Ntex=o.period*o.tf*2;
                    for i= 1:o.Ntex
                        img = radCheck(:,:,1); %reset your image to the basic polar checkerboard each time
                        img(r<.04)=0;
                        img(r>1) = 0;
                        img = (-1)^i*img;
                        if i > o.stimPeriod*o.tf*2
                            img = 0;
                        end
                        % make and draw your texture
                        textureIndex(i)=Screen('MakeTexture', o.winPtr, (img+1)*127.5);
            %             waitbar(i/(o.period*o.tf*2), h);
                        if ~mod(i,10)
                            fprintf('.');
                        end
                    end
                otherwise
                    %o.Ntex=o.period*o.tf*2;
                    for i= 1:o.Ntex
                        flipTime=(i-1)/(o.tf*2);
                        %each cycle goes from 0 to 1
                        phase_step = (rem(flipTime+o.startPhase*o.period, o.period)/o.period);
 
        %                 if i == 1
        %                     phase = o.startPhase;
        %                 elseif ~mod(i-1,12) % 24 times...
        %                     phase = phase + 1/24;
        %                 end
                        phase_step=rem(phase_step,1+eps);
                        img = radCheck(:,:,mod(i-1,o.motionSteps)+1); %reset your image to the basic polar checkerboard each time
                        if ~mod(i,48)
                            trigger = -1;
                            toggle = toggle * trigger;
                        end
        
                        if toggle > 0
                            img = radCheck(:,:,o.motionSteps-mod(i-1,o.motionSteps));
                        end
        
                        
                        o.phase=o.minphase+(o.maxphase-o.minphase)*phase_step; %put in min and max here
                        

                        switch o.stim
                            case 'ring'
                                %phase=2*pi*phase_step; %put in min and max here
                                %determine where the ring should be
                                radLo = o.phase - .5*o.ringWidth/o.nRad;
                                radHi = o.phase + .5*o.ringWidth/o.nRad;
                                radHi = min(radHi, 1); % To not show two eccentricities
        
                                %Zero out the areas of the image that you want grey
                                if radLo < 0  %ring is close to fovea
                                    img(r > radHi & r<radLo+1)=0;
                                elseif radHi > 1 %ring is outside of circle
                                    img(r>radHi-1 & r<radLo)=0;
                                else
                                    img(r<radLo) = 0;
                                    img(r>radHi) = 0;
                                end
                                img(r<(o.innerRad*o.pixPerDeg)/diam_px)=0;%img(r<.04)=0;
                                img(r>1) = 0;
        
                            case 'wedge'
                                %phase=2*pi*phase_step; %put in min and max here
                                %determine where the wedge should be
                                angLo = o.phase- .5*o.wedgeWidth/o.nAng;
                                angHi = o.phase+ .5*o.wedgeWidth/o.nAng;
        
                                %Zero out the areas of the image that you want grey    
                                if angLo < 0  
                                    img(a > angHi & a<(angLo+1*(2*pi)))=0;
                                elseif angLo > 2*pi
                                    img(a>(angHi-1*(2*pi)) | a<(angLo-1*(2*pi))) = 0;
                                elseif angHi > 2*pi
                                    img(a>(angHi-1*(2*pi)) & a<angLo*(2*pi)) = 0;
                                else
                                    img(a<angLo) = 0;
                                    img(a>angHi) = 0;
                                end
                                %ring is close to fovea
                                img(r<(o.innerRad*o.pixPerDeg)/diam_px)=0;%img(r<.04)=0;
                                img(r>1) = 0;
        
                            case 'meridian'
                                %phase=2*pi*phase_step; %put in min and max here
                                %Zero out the areas of the image that you want grey
                                if phase>=.5 %horizontal meridian
                                    img(a> o.meriThick/2 & a<.5-o.meriThick/2)=0;
                                    img(a>.5+o.meriThick/2 & a<1-o.meriThick/2)=0;
                                else %vertical meridian
                                    img(a<= .25-o.meriThick/2)=0;
                                    img(a>=.25+o.meriThick/2 & a<=.75-o.meriThick/2)=0;
                                    img(a>=.75+o.meriThick/2 & a<=1)=0;
                                end
                                img(r<.04)=0;
                                img(r>1) = 0;
                        end
                        %make it switch between B/W and W/B
                    %     img = (-1)^i*img;
                   % imagesc(img);pause(0.1);
                        %make and draw your texture
                         textureIndex(i)=Screen('MakeTexture', o.winPtr, (img+1)*127.5);
        %                    textureIndex(i)=Screen('MakeTexture', o.winPtr, (img+1)/2);
            %             waitbar(i/(o.period*o.tf*2), h);
                        if ~mod(i,10)
                            fprintf('.');
                        end
                    end
            end % switch

        %% Make full 2D texture in one go (don't do this)
        %Filter with a gaussian window
%         dim=size(square,1);
%         [x,y] = meshgrid((1:dim)-dim/2);
%         g = exp(-(x.^2+y.^2)/(2*(dim/6)^2));
%         
%         im0 = ((g.*double(square)) + o.bkgd*(1-g)); 
%         %im0 = uint8((g.*double(square)) + o.bkgd*(1-g)); 
%         %im = ((g.*double(square)));
%         
%         %the follow snippet is from fixbarRF
%         linetex=[0,0];
%         %Filter with a Raised Cosine instead
%         %dim=size(square,1);
%         dim=size(linetex,2);
%         [x,y] = meshgrid((1:dim)-dim/2);
%         [th,r] = cart2pol(x,y);
%         
%         edge=round(dim/10); %placeholder
%         inner=dim/2-edge;
%         outer=dim/2;
%         raisedcosn=(.5*cosd((r-inner)/edge*180)+.5);
%         
%         z=zeros(dim);
%         z(r<(inner))=1;
%         z(r>=(inner))=raisedcosn(r>=(inner));
%         z(r>(outer))=0;
%         
%         %Alpha channel only, paste into alpha channel
%         g(:,:,4)=z*255;
%         g(:,:,1:3)=ones(dim,dim,3)*o.bkgd;
%         %g=repmat(z,1,1,3)*255;
%         
%         %Create a filter to blend with the oneD noise
%         o.filt = Screen('MakeTexture',o.winPtr,g);  
%         
%         g=z;
%         %im0 = ((g.*double(square)) + o.bkgd*(1-g)); 
%         %im0 = uint8((g.*double(square)) + o.bkgd*(1-g)); 
%         %im = ((g.*double(square)));
%         
%         if (o.contrast > 0)
%             t1 = 255 * (squeeze(mean(g,3)) > 0.05);
%         else
%             t1 = 255 * squeeze(mean(g,3));
%         end      


        for i=1:o.Ntex
            o.texDim(i)=diam_px;
%             o.tex(i) = Screen('MakeTexture',o.winPtr, ...
%                 linetex(i,:));        
            o.tex(i)=textureIndex(i);
        end
 
        
    end
    
    function CloseUp(o)
       if ~isempty(o.tex)
          for i = 1:size(o.tex,2) 
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
          o.drawTexImage(o.texnum);
      else
          %Textures are already random, do we need to shuffle here?
          rd = randi(o.rng, o.Ntex);  
          o.drawTexImage(rd);
       end
    end
        
    function afterFrame(o)
    end
    
    function drawTexImage(o,texnum)

       if ( (texnum>0) && (texnum <= size(o.tex,2)) ) 
         if (~isempty(o.tex(texnum)))
%            rect = kron([1,1],o.position) + kron(o.pxradius,[-1, -1, +1, +1]);
%            texrect = [0 0 o.texDim(texnum) o.texDim(texnum)];
            texrect= o.srcRect;
            rect=o.destRect;
           
          % ori = o.prefori;
           %disp(o.tex(texnum))
           %Screen(o.winPtr,'BlendFunction', GL_ONE, GL_ZERO);%NO blending
           Screen(o.winPtr,'BlendFunction',GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
           Screen('DrawTexture',o.winPtr,o.tex(texnum),texrect,rect,[],[],o.contrast);
           
%            %Set alpha blending to overwrite alpha channel only
%            Screen(o.winPtr,'BlendFunction', GL_ONE_MINUS_SRC_ALPHA, GL_SRC_ALPHA, [1 1 1 1]);
%            
%            %Filter with overlayed cosine aperture
%            Screen('DrawTexture',o.winPtr,o.filt,texrect,rect,ori);
%            
           %Return alpha blending to standard form
           Screen(o.winPtr,'BlendFunction',GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
         end
       end
    end
    
    function varargout = getImage(o, rect, binsize)
        
        if o.winPtr~=0
            warning('oneDnoise: getImage: only works if you constructed the object with winPtr=0')
        end
        
        if nargin < 3
            binsize = 1;
        end
        
        if nargin < 2
            rect = o.position([1 2 1 2]) + [-1 -1 1 1].*o.pxradius/2;
        end
        

        
        I = o.tex{o.texnum};
        I = double(I);
        alpha = squeeze(I(:,:,4))./255;
        I(:,:,4) = [];
        for i = 1:3
            I(:,:,i) = I(:,:,i).*alpha + 127.*(1-alpha);
        end
        
        texrect = kron([1,1],o.position) + kron(o.pxradius,[-1, -1, +1, +1]);
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


