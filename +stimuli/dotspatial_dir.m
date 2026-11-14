classdef dotspatial_dir < stimuli.stimulus
    %DOTSPATIALNOISE uses the dots class for spatiotemporal reverse
    %correlation
    %   Detailed explanation goes here

    properties
        updateEveryNFrames % if the update should only run every
        frameUpdate
        contrast
        sigma
        pixPerDeg double 
        size double % pixels
        speed double % pixels/s
        direction double % deg.
        numDots double
        lifetime double % dot lifetime (frames)
        maxRadius double % maximum radius (pixels)
        position double % aperture position (x,y; pixels)
        color double
        dotType double
        dirStep double 
        ndirs double 
        refreshRate double 



    end

    properties (GetAccess = public, SetAccess = {?stimuli.stimulus})
        % also the initialization of the fundemental parameters 
        % cartessian coordinates in drawdots 
        x % x coords (pixels)
        y % y coords (pixels)
        z % z coords (pixels)
        a
        b
        tempy
        tempx
        
        % arduino changes 
        xa
        ya
        ra

        % distances in real world
        h = 120;
        yr % y distance in reality 
        xr % x distance in reality 
        
        % change of displacements
        dx % x direction translation 
        dy % y direction  translation (moving towards the animal)
        dr % rotation (the motion vector rotation)
        dth = 0; % rotation angle in visual degree  
        
        % frames remaining for each dot
        frameCnt
        
        % dotType:
        %
        %   0 - square dots (default)
        %   1 - round, anit-aliased dots (favour performance)
        %   2 - round, anti-aliased dots (favour quality)
        %   3 - round, anti-aliased dots (built-in shader)
        %   4 - square dots (built-in shader)
        
    end

    properties (Access = public) %{?stimuli.stimulus}
        winPtr % ptb window
        winRect % ptbwindow size
        winCtr % center of window
    end

    methods
        function obj = dotspatial_dir(winPtr, varargin)

            obj = obj@stimuli.stimulus();
            obj.winPtr = winPtr;
            if winPtr > 0
                obj.winRect = Screen('Rect', obj.winPtr);
                obj.winCtr = obj.winRect(3:4)/2;
            end

            ip = inputParser();
            ip.KeepUnmatched = true;
            ip.StructExpand = true;
            ip.addParameter('size',35.0); % pixels?
            ip.addParameter('speed',10); % deg./s
            ip.addParameter('dirStep',30);
            ip.addParameter('direction',[0:30:330],@(x) isscalar(x) && isreal(x)); % deg.
            ip.addParameter('ndirs',12);
            ip.addParameter('numDots',150,@(x) ceil(x));
            ip.addParameter('lifetime',Inf);
            ip.addParameter('maxRadius',25.0); % deg.
            
            ip.addParameter('position',[0.0,0.0],@(x) isvector(x) && isreal(x)); % [x,y] (pixels)
            
            ip.addParameter('color',[0,0,0]);
            ip.addParameter('visible',true)
            ip.addParameter('contrast', .5)
            ip.addParameter('updateEveryNFrames', 1)
            ip.addParameter('frameUpdate', 0)
            ip.addParameter('sigma', inf)
          
            ip.addParameter('pixPerDeg',50)
            ip.addParameter('dotType',1)
            ip.addParameter('refreshRate',240)
            ip.parse(varargin{:});
            obj.lifetime = Inf;

            args = ip.Results;
              
            obj.size = args.size;
            obj.speed = args.speed;
            obj.direction = args.direction;
            obj.numDots = args.numDots;
            obj.lifetime = args.lifetime;
            obj.maxRadius = args.maxRadius;
            obj.position = args.position;
            obj.color = args.color;
            obj.stimValue = args.visible;
            obj.contrast = ip.Results.contrast;
            obj.updateEveryNFrames = ip.Results.updateEveryNFrames;
            obj.frameUpdate = ip.Results.frameUpdate;
            obj.sigma = ip.Results.sigma;
            obj.maxRadius = inf;
            obj.position = obj.winCtr;
            obj.dotType = 1;
            obj.speed = ip.Results.speed;
            obj.pixPerDeg = args.pixPerDeg;
            obj.dotType = 1;
            obj.refreshRate = 240;

        end

        function beforeTrial(obj,seed)

            if nargin > 1
                obj.setRandomSeed(seed);
            else
                % important, set the random seed
                obj.setRandomSeed();
            end

            obj.initDots(1:obj.numDots,0,0);


            % frameUpdate needs to be 0 for init to work
            obj.frameUpdate = 0;

            % call parent function (calls initDots)
            %beforeTrial@stimuli.dotsbase(obj)

            if obj.lifetime ~= Inf
                obj.frameCnt = randi(obj.rng, obj.lifetime,obj.numDots,1); % 1:numDots
            else
                obj.frameCnt = inf(obj.numDots,1);
            end

        end

        function beforeFrame(obj)
            obj.drawDots();
        end

        function afterFrame(obj,xshift,yshift,modd,fc)
        
            obj.moveDots(xshift,yshift,modd,fc)

            obj.frameUpdate = mod(obj.frameUpdate +1, obj.updateEveryNFrames);

        end


        function initDots(obj, idx, xshift, yshift)
            %INITDOTS random x,y values for the dots - not coordinates yet 
            % These values are unitless? Should be centimeters in 'real'
            % world
            n = numel(idx);
            
            obj.x(idx) = rand(obj.rng, 1, n) * obj.winRect(3)+ -obj.winRect(3)/2;
            obj.y(idx) = rand(obj.rng, 1, n) * obj.winRect(4)+ -obj.winRect(4)/2;

            if isempty(obj.z)
             for i = 1:n     
                if idx(i)<= 225
                    obj.z(i) = 0;
                elseif idx(i) > 225
                    obj.z(i) = round((rand(1))*200);
                    
                end 
             end 
            end 
            
            obj.tempy(idx) = obj.y(idx);
            obj.tempx(idx) = obj.x(idx);

            obj.dx(idx) = xshift;
            obj.dy(idx) = yshift;


            if n == obj.numDots
                obj.color = 127 + round(obj.contrast*127*[1; 1; 1]*sign( (rand(obj.rng, 1, n)<.5)-.5));
            else
                obj.color(:,idx) = 127 + round(obj.contrast*127*[1; 1; 1]*sign( (rand(obj.rng, 1, n)<.5)-.5));
            end

            

        end

        function moveDots(obj, xshift, yshift,modd,fc)
            if modd == 1 && fc>0
                obj.initDots(1:obj.numDots,xshift,yshift);
            end 
            
            obj.dx= xshift;
            obj.dy = yshift;
            %obj.dy =  - obj.speed *obj.pixPerDeg* 0.01667;

            % calculate future position -  xr/yr = x-renew, y-renew 
            obj.xr = obj.x + obj.dx;
            obj.yr = obj.y + obj.dy;

            obj.tempy = obj.yr;
            obj.tempx = obj.xr;
            % temp rotation calulation test 
            obj.y = obj.tempy;
            obj.x = obj.tempx;
            
            % opt1: replot the dot when hit the bounds - reapear at the other end
            % of the aperture 
            win = obj.winRect(3:4)/2;
            obj.x(obj.x > win(1)) = -win(1);
            obj.x(obj.x < -win(1)) = win(1);
            obj.y(obj.y > win(2)) = -win(2);
            obj.y(obj.y < -win(2)) = win(2);

            % opt2: replot the dot when hir the bounds - but randomize the
            % repearring location for both xy 

            % win = [obj.winRect(3)./2, obj.winRect(4)./2];
            % idx = find((obj.x > win(1)) | (obj.x < -win(1)) | (obj.y > win(2))|(obj.y < -win(2)));
            % 
            % for i =1:length(idx)
            %     obj.x(idx(i)) = rand(obj.rng, 1, 1) * obj.winRect(3)+ -obj.winRect(3)/2;
            %     obj.y(idx(i)) = rand(obj.rng, 1, 1) * obj.winRect(4)+ -obj.winRect(4)/2;
            % 
            % end 
  
            
        end

        function drawDots(obj)
            if ~obj.stimValue
                return
            end
            
            [sourceFactorOld, destinationFactorOld] = Screen('BlendFunction', obj.winPtr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            Screen('DrawDots',obj.winPtr,[obj.x(:), -1*obj.y(:)]', obj.size, obj.color, obj.position, obj.dotType);
            Screen('BlendFunction', obj.winPtr, sourceFactorOld, destinationFactorOld);
        end
       

        
        function CloseUp(obj) % empty

        end
    end

    methods (Static)
        function [xx, yy] = rotate(x,y,th)
            % rotate (x,y) by angle th
            
            n = length(th);
            
            xx = zeros([n,1]);
            yy = zeros([n,1]);
            
            for ii = 1:n
                % calculate rotation matrix
                R = [cos(th(ii)) -sin(th(ii)); ...
                    sin(th(ii))  cos(th(ii))];
                
                tmp = R * [x(ii), y(ii)]';
                xx(ii) = tmp(1,:);
                yy(ii) = tmp(2,:);
            end
        end
    end % methods
end

