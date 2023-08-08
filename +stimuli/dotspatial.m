classdef dotspatial < stimuli.stimulus
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
        function obj = dotspatial(winPtr, varargin)

            obj = obj@stimuli.stimulus();
            obj.winPtr = winPtr;
            if winPtr > 0
                obj.winRect = Screen('Rect', obj.winPtr);
                obj.winCtr = obj.winRect(3:4)/2;
            end

            ip = inputParser();
            ip.KeepUnmatched = true;
            ip.StructExpand = true;
            ip.addParameter('size',25.0); % pixels?
            ip.addParameter('speed',5); % deg./s
            ip.addParameter('direction',180.0,@(x) isscalar(x) && isreal(x)); % deg.
            ip.addParameter('numDots',300,@(x) ceil(x));
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

        function afterFrame(obj,xshift,yshift)
        
            obj.moveDots(xshift,yshift)

            obj.frameUpdate = mod(obj.frameUpdate +1, obj.updateEveryNFrames);

        end


        function initDots(obj, idx, xshift, yshift)
            %INITDOTS random x,y values for the dots - not coordinates yet 
            % These values are unitless? Should be centimeters in 'real'
            % world
            n = numel(idx);
            
            obj.x(idx) = (rand(obj.rng, 1, n)-0.5) * 300; %3 m wide plain
            obj.y(idx) = rand(obj.rng, 1, n) * 300; % seeing 3m into horizon 

            if isempty(obj.z)
             for i = 1:n     
                if idx(i)<= 225
                    obj.z(i) = 0;
                elseif idx(i) > 225
                    obj.z(i) = round((rand(1))*200);
                    
                end 
             end 
            end 
            
            obj.yr(idx)  = obj.y(idx);
            obj.xr(idx)  = obj.x(idx);
           
            obj.a(idx) = rad2deg(atan((obj.y(idx))./(- obj.z(idx) + 15)));
            obj.b(idx) = rad2deg(atan(obj.x(idx)./obj.y(idx)));

            obj.y(idx) = 2*(obj.a(idx)./90 -sign(obj.a(idx)))* obj.winRect(4)/2 + 10;
            obj.x(idx) = 2*obj.b(idx)./90 * obj.winRect(3)/2;

            obj.tempy(idx) = obj.y(idx);
            obj.tempx(idx) = obj.x(idx);

            obj.dx(idx) = xshift;
            obj.dy(idx) = yshift;

            
            % passive viewing condition 
            %obj.dy(idx) =  - obj.speed *obj.pixPerDeg* 0.01667; % 1./frameRate

            % temp rotation calculation
            obj.y(idx) = obj.tempx(idx).* sin(deg2rad(obj.dth)) + obj.tempy(idx).*(cos(deg2rad(obj.dth)));
            obj.x(idx) = obj.tempx(idx).* cos(deg2rad(obj.dth)) - obj.tempy(idx).*(sin(deg2rad(obj.dth)));
            

            if n == obj.numDots
                obj.color = 127 + round(obj.contrast*127*[1; 1; 1]*sign( (rand(obj.rng, 1, n)<.5)-.5));
            else
                obj.color(:,idx) = 127 + round(obj.contrast*127*[1; 1; 1]*sign( (rand(obj.rng, 1, n)<.5)-.5));
            end

            

        end

        function moveDots(obj, xshift, yshift)
            
            obj.dx= xshift;
            obj.dy = yshift;
            %obj.dy =  - obj.speed *obj.pixPerDeg* 0.01667;

            % calculate future position
            obj.xr = obj.xr + obj.dx;
            obj.yr = obj.yr + obj.dy;
            obj.a = rad2deg(atan(obj.yr./(-obj.z + 15)));
            obj.b = rad2deg(atan(obj.xr./obj.yr));
            
            obj.y = 2*(obj.a./90-sign(obj.a)) * obj.winRect(4)/2 + 10;
            obj.x = 2*obj.b./90 * obj.winRect(3)/2;

            obj.tempy = obj.y;
            obj.tempx = obj.x;
            % temp rotation calulation test 
            obj.y = obj.tempx.* sin(deg2rad(obj.dth)) + obj.tempy.*(cos(deg2rad(obj.dth)));
            obj.x = obj.tempx.* cos(deg2rad(obj.dth)) - obj.tempy.*(sin(deg2rad(obj.dth)));

            win = [obj.winRect(3)/2, obj.winRect(4)./2];
            
            idx = find(obj.x > win(1) | obj.x < -win(1) | obj.y > win(2)|obj.y < -win(2) |obj.yr <= 0)'; 
            if ~isempty(idx)
            
                % (re-)place dots randomly within the aperture
                obj.initDots(idx,xshift,yshift);
            end  
            
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

