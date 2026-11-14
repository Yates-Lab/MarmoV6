classdef opticflow < stimuli.stimulus
  % Optic flow stimulus using dots, basing format on stimuli.gratings and
  % Jake's demo code. See also Penny's stimuli.dotspatial for VR
  % application

  % Matlab class for drawing an optic flow field using the psych. toolbox.
  %
  % The class constructor can be called with a range of arguments:
  %   position - center of FOV in 
  %   focal length
  %   depth
  %   size       - dot size (pixels)
  %   speed      - flow speed vxyz (pixels/frame),
  %   nDots    - number of dots
  %   color

  
  % 19-03-2024 - Declan Rowley
  
  properties (Access = public)
    position double = [0.0, 0.0]; % [x,y] (pixels, from top left)
    f double = 0.01;
    depth double = 2;
    dotdepth double = 1;
    size double = 1;
    vxyz double = [0 0 1]; %flow speed [x,y,z]
    nDots double = 500;
    transparent double = 0.5;  % from 0 to 1, how transparent
    pixperdeg double = 0;  % set non-zero to use for CPD computation
    screenRect = [];   % if radius Inf, then fill whole area
    colour = [1 1 1];
    bkgd double = 127;  
    balancedDots logical = false; % equal light/dark dot counts around bkgd
    dotContrast double = 1; % symmetric contrast in the display's 0-255 range
    dotPolarity double = []; % -1 dark, 0 background, +1 light
    dotColours double = []; % precomputed Screen DrawDots colour matrix
    polarityColours double = []; % 3x2 RGB columns: negative, positive endpoint
    neutralColour double = []; % 3x1 RGB neutral point for zero-polarity dots
    dotType double = 1; % Screen DrawDots type; 1 = anti-aliased (legacy)
    exactColour logical = false; % square dots, blending off: pixels equal supplied RGB
    lastBlendFunction cell = {}; % {source,destination} in effect for the last draw
    cachedReplacementX double = [];
    cachedReplacementY double = [];
    trialPlacementReady logical = false;
    cachedReplacementCount double = 0;
    minSeparationPix double = 0; % minimum spacing among like-polarity dots
    placementAttempts double = 50; % rejection samples before best-candidate fallback
    placementFallbackCount double = 0; % placements that missed requested spacing
    placementCandidateCount double = 0; % candidates evaluated this trial
    placementDistanceChecks double = 0; % local neighbor distances evaluated
    placementTimeSeconds double = 0; % CPU time spent placing dots
    placementCalls double = 0;
    % could add an aperture radius, for now fullscreen 
    maxRadius double; % maximum radius (pixels), default to Inf
    Xtop double; % max X (pixels) screenRect(3)
    Xbot double; % min X (pixels) screenRect(1);
    %Switching these
    Ytop double; % max Y (pixels) screenRect(2); More negative counting down from top
    Ybot double; % min Y (pixels) screenRect(4);

    % framecount to give dots a lifetime?
    frameCnt double;
    lifetime double = Inf;
    centerDecay logical = true; %flag to cull central dots
    centerDecayRadii double = [0.5 1.5 2.5 5]; % dot-size units; TDM was [0.15 0.25 0.5 1.5]
    centerDecaySteps double = [1 5 15 30]; % replace every Nth dot inside each radius

    % cartessian coordinates (relative to center of screen/aperture?)
    x; % x coords (pixels) (nDots, 1)
    y; % y coords (pixels)
    z; 
    
    % cartesian displacements
    dx; % pixels per frame?
    dy; % pixels per frame?

    %speeds
    fs;
    zs;
  end
        
  properties (Access = private)
    winPtr; % ptb window

  end
  
  methods (Access = public)
    function o = opticflow(winPtr,varargin) % marmoview's initCmd?
      o.winPtr = winPtr;

      if nargin == 1
        return
      end

      % initialise input parser
      args = varargin;
      p = inputParser;
      p.StructExpand = true;
      
      p.addParameter('position',o.position, isfloat); % [x,y] (pixels)
    p.addParameter('f',o.f, isfloat); % focus
    p.addParameter('depth',o.depth, isfloat); % depth of focus
    p.addParameter('dotdepth',o.dotdepth, isfloat); % depth of dots

    p.addParameter('size',o.size, isfloat); % dotsize
    p.addParameter('vxyz',o.vxyz, isfloat); % speed xyz of dots
    p.addParameter('nDots',o.nDots, isfloat); % number of dots
    p.addParameter('transparent',o.transparent, isfloat); % from 0 to 1, how transparent
    %p.addParameter('pixperdeg',o.pixperdeg, isfloat); % [x,y] (pixels)
    p.addParameter('colour',o.colour, isfloat); % dot colour
    p.addParameter('bkgd',o.bkgd, isfloat); % 
    p.addParameter('maxRadius',o.maxRadius, isfloat); % maximum radius (pixels), default to Inf
    p.addParameter('Xtop',o.Xtop, isfloat); % max X (pixels)
    p.addParameter('Xbot',o.Xbot, isfloat); % min X (pixels)
    p.addParameter('Ytop',o.Ytop, isfloat); % max Y (pixels)
    p.addParameter('Ybot',o.Ybot, isfloat); % min Y (pixels)
    p.addParameter('centerDecay',o.centerDecay, @(x) islogical(x) || isnumeric(x));
    p.addParameter('centerDecayRadii',o.centerDecayRadii, isfloat);
    p.addParameter('centerDecaySteps',o.centerDecaySteps, isfloat);
    p.addParameter('balancedDots',o.balancedDots, @(x) islogical(x) || isnumeric(x));
    p.addParameter('dotContrast',o.dotContrast, isfloat);
    p.addParameter('polarityColours',o.polarityColours, isfloat);
    p.addParameter('neutralColour',o.neutralColour, isfloat);
    p.addParameter('minSeparationPix',o.minSeparationPix, isfloat);
    p.addParameter('placementAttempts',o.placementAttempts, isfloat);


      try
        p.parse(args{:});
      catch
        warning('Failed to parse name-value arguments.');
        return;
      end
      
      args = p.Results;
    
      o.position = args.position;
      o.f = args.f;
      o.depth = args.depth;
      o.dotdepth = args.dotdepth;
      o.size = args.size;
      o.vxyz = args.vxyz;
      o.nDots = args.nDots;
      o.transparent = args.transparent;
      o.colour = args.colour;
      o.bkgd = args.bkgd;
      o.maxRadius = args.maxRadius;
      o.Xtop = args.Xtop;
      o.Xbot = args.Xbot;
      o.Ytop = args.Ytop;
      o.Ybot = args.Ybot;
      o.centerDecay = logical(args.centerDecay);
      o.centerDecayRadii = args.centerDecayRadii;
      o.centerDecaySteps = args.centerDecaySteps;
      o.balancedDots = logical(args.balancedDots);
      o.dotContrast = args.dotContrast;
      o.polarityColours = args.polarityColours;
      o.neutralColour = args.neutralColour;
      o.minSeparationPix = max(0,args.minSeparationPix);
      o.placementAttempts = max(1,round(args.placementAttempts));

    end
    

    function beforeTrial(o)
      o.placementFallbackCount = 0;
      o.placementCandidateCount = 0;
      o.placementDistanceChecks = 0;
      o.placementTimeSeconds = 0;
      o.placementCalls = 0;
      o.cachedReplacementCount = 0;
      o.trialPlacementReady = false;
      o.cachedReplacementX = [];
      o.cachedReplacementY = [];
      o.fs = repmat(-o.f,o.nDots,1);
      o.zs = zeros(o.nDots, 1);

      if o.exactColour
        % Anti-aliased edges and alpha blending mix colours in the
        % framebuffer's (gamma-encoded) space, leaving the calibrated axis.
        if ~ismember(o.dotType,[0 4])
          error('opticflow:ExactColourDotType', ...
            'exactColour requires square, non-anti-aliased dots (dotType 0 or 4).');
        end
        if ~isempty(o.polarityColours) && o.dotContrast ~= 1
          error('opticflow:ExactColourContrast', ...
            'exactColour requires dotContrast 1; scale contrast in linear space instead.');
        end
      end

      if o.balancedDots
        nPairs = floor(o.nDots/2);
        o.dotPolarity = [ones(nPairs,1); -ones(nPairs,1); ...
          zeros(o.nDots - 2*nPairs,1)];
        o.dotPolarity = o.dotPolarity(randperm(o.rng,o.nDots));
        contrast = min(max(o.dotContrast,0),1);
        if ~isempty(o.polarityColours)
          if ~isequal(size(o.polarityColours),[3 2]) || ...
                  any(~isfinite(o.polarityColours(:))) || ...
                  any(o.polarityColours(:) < 0) || ...
                  any(o.polarityColours(:) > 255)
            error('opticflow:PolarityColours', ...
              'polarityColours must be a finite 3x2 RGB matrix in [0,255].');
          end
          if isempty(o.neutralColour)
            neutral = mean(o.polarityColours,2);
          else
            neutral = o.neutralColour(:);
          end
          if numel(neutral) ~= 3 || any(~isfinite(neutral)) || ...
                  any(neutral < 0) || any(neutral > 255)
            error('opticflow:NeutralColour', ...
              'neutralColour must contain three finite RGB values in [0,255].');
          end
          if contrast == 1
            endpoints = o.polarityColours; % bit-exact calibrated values
          else
            endpoints = neutral + contrast*(o.polarityColours-neutral);
          end
          o.dotColours = repmat(neutral,1,o.nDots);
          o.dotColours(:,o.dotPolarity < 0) = repmat(endpoints(:,1),1,nnz(o.dotPolarity < 0));
          o.dotColours(:,o.dotPolarity > 0) = repmat(endpoints(:,2),1,nnz(o.dotPolarity > 0));
        else
          maxDelta = min(o.bkgd,255-o.bkgd);
          dotLevels = o.bkgd + contrast*maxDelta*o.dotPolarity;
          o.dotColours = repmat(dotLevels(:).',3,1);
        end
      else
        o.dotPolarity = [];
        o.dotColours = o.colour;
      end

      % Polarity is assigned first so minimum-distance sampling can suppress
      % same-sign clusters while leaving opposite signs independent.
      o.initDots(1:o.nDots);
      if o.minSeparationPix > 0
          o.cachedReplacementX = o.x;
          o.cachedReplacementY = o.y;
          o.trialPlacementReady = true;
      end

      % initialise dots' lifetime
      if o.lifetime ~= Inf
        o.frameCnt = randi(o.rng, o.lifetime,o.nDots,1); % 1:nDots
      else
        o.frameCnt = inf(o.nDots,1);
      end
    end
    
    function beforeFrame(o)
      o.drawDots();
    end
        

    function afterFrame(o)
        % Update positions
        Ax = [o.fs o.zs o.x-o.position(1)];
        Ay = [o.zs o.fs o.y-o.position(2)];
        o.dx = Ax*o.vxyz'./o.z;
        o.dy = Ay*o.vxyz'./o.z;
        
         % decrement frame counters
        o.frameCnt = o.frameCnt - 1;

        o.moveDots();
    end
    
    
    function CloseUp(o)
    end
    
  end % methods
    


    
  methods (Access = public)        
    function initDots(o,idx)
      % initialises dot positions
      n = length(idx); % the number of dots to (re-)place
      
      o.frameCnt(idx) = o.lifetime; % default: Inf
      
      if o.trialPlacementReady && o.minSeparationPix > 0 && ...
              numel(o.cachedReplacementX) == o.nDots
          % Recycle the pre-trial minimum-distance layout. No spatial-grid
          % construction or rejection sampling occurs during presentation.
          x_ = o.cachedReplacementX(idx);
          y_ = o.cachedReplacementY(idx);
          o.cachedReplacementCount = o.cachedReplacementCount + numel(idx);
      else
          placementTimer = tic;
          [x_,y_] = o.samplePositions(idx);
          o.placementTimeSeconds = o.placementTimeSeconds + toc(placementTimer);
          o.placementCalls = o.placementCalls + 1;
      end
      o.x(idx,1) = x_;
      o.y(idx,1) = y_;
      
      o.z = o.dotdepth + o.depth;

      % set displacements (dx and dy) for each dot
%      [o.dx(idx),o.dy(idx)] = pol2cart(o.direction.*(pi/180),o.speed);
%       o.dx(idx) = dx_;
%       o.dy(idx) = dy_;

        Ax = [o.fs o.zs o.x-o.position(1)];
        Ay = [o.zs o.fs o.y-o.position(2)];
        o.dx = Ax*o.vxyz'./o.z;
        o.dy = Ay*o.vxyz'./o.z;
      
    end

    function [xNew,yNew] = samplePositions(o,idx)
      % Sequential minimum-distance sampling. In balanced mode the spacing
      % constraint is polarity-specific, suppressing light-only and
      % dark-only clusters without forcing light/dark dipoles.
      n = numel(idx);
      xNew = nan(n,1);
      yNew = nan(n,1);

      if o.minSeparationPix <= 0
          [xNew,yNew] = o.randomPositions(n);
          return
      end

      existingMask = true(o.nDots,1);
      existingMask(idx) = false;
      if numel(o.x) < o.nDots
          existingX = zeros(0,1);
          existingY = zeros(0,1);
          existingPolarity = zeros(0,1);
      else
          existingMask = existingMask & isfinite(o.x(:)) & isfinite(o.y(:));
          existingX = o.x(existingMask);
          existingY = o.y(existingMask);
          if o.balancedDots
              existingPolarity = o.dotPolarity(existingMask);
          else
              existingPolarity = ones(nnz(existingMask),1);
          end
      end

      minDistanceSquared = o.minSeparationPix.^2;
      cellSize = o.minSeparationPix;
      if isinf(o.maxRadius)
          xMin = o.Xbot;
          xMax = o.Xtop;
          yMin = o.Ytop;
          yMax = o.Ybot;
      else
          xMin = -o.maxRadius;
          xMax = o.maxRadius;
          yMin = -o.maxRadius;
          yMax = o.maxRadius;
      end
      nCols = max(1,ceil((xMax-xMin)/cellSize));
      nRows = max(1,ceil((yMax-yMin)/cellSize));
      nCells = nCols*nRows;
      buckets = cell(3*nCells,1);
      existingGroup = o.polarityGroup(existingPolarity);
      for kk = 1:numel(existingX)
          column = min(nCols,max(1,floor((existingX(kk)-xMin)/cellSize)+1));
          row = min(nRows,max(1,floor((existingY(kk)-yMin)/cellSize)+1));
          cellIndex = row + (column-1)*nRows + (existingGroup(kk)-1)*nCells;
          buckets{cellIndex}(end+1) = kk;
      end

      for ii = 1:n
          dotIndex = idx(ii);
          if o.balancedDots
              polarity = o.dotPolarity(dotIndex);
          else
              polarity = 1;
          end
          group = o.polarityGroup(polarity);
          bestDistanceSquared = -Inf;
          bestX = NaN;
          bestY = NaN;
          accepted = false;

          for attempt = 1:o.placementAttempts
              o.placementCandidateCount = o.placementCandidateCount + 1;
              [candidateX,candidateY] = o.randomPosition();
              if isinf(o.maxRadius) && ...
                      hypot(candidateX-o.position(1),candidateY-o.position(2)) < 2.5*o.size
                  continue
              end
              column = min(nCols,max(1,floor((candidateX-xMin)/cellSize)+1));
              row = min(nRows,max(1,floor((candidateY-yMin)/cellSize)+1));
              neighborIndices = [];
              for neighborColumn = max(1,column-1):min(nCols,column+1)
                  for neighborRow = max(1,row-1):min(nRows,row+1)
                      cellIndex = neighborRow + (neighborColumn-1)*nRows + ...
                          (group-1)*nCells;
                      neighborIndices = [neighborIndices buckets{cellIndex}]; %#ok<AGROW>
                  end
              end
              o.placementDistanceChecks = o.placementDistanceChecks + ...
                  numel(neighborIndices);
              if ~isempty(neighborIndices)
                  nearestSquared = min((existingX(neighborIndices)-candidateX).^2 + ...
                      (existingY(neighborIndices)-candidateY).^2);
              else
                  nearestSquared = Inf;
              end
              if nearestSquared > bestDistanceSquared
                  bestDistanceSquared = nearestSquared;
                  bestX = candidateX;
                  bestY = candidateY;
              end
              if nearestSquared >= minDistanceSquared
                  accepted = true;
                  break
              end
          end

          if ~accepted
              o.placementFallbackCount = o.placementFallbackCount + 1;
          end
          while ~isfinite(bestX) || ~isfinite(bestY)
              [bestX,bestY] = o.randomPosition();
              if ~isinf(o.maxRadius) || ...
                      hypot(bestX-o.position(1),bestY-o.position(2)) >= 2.5*o.size
                  break
              end
          end
          xNew(ii) = bestX;
          yNew(ii) = bestY;
          existingX(end+1,1) = bestX;
          existingY(end+1,1) = bestY;
          existingPolarity(end+1,1) = polarity;
          cellIndex = min(nRows,max(1,floor((bestY-yMin)/cellSize)+1)) + ...
              (min(nCols,max(1,floor((bestX-xMin)/cellSize)+1))-1)*nRows + ...
              (group-1)*nCells;
          buckets{cellIndex}(end+1) = numel(existingX);
      end
    end

    function [x,y] = randomPositions(o,n)
      if isinf(o.maxRadius)
          x = rand(o.rng,n,1)*(o.Xtop-o.Xbot) + o.Xbot;
          y = rand(o.rng,n,1)*(o.Ytop-o.Ybot) + o.Ybot;
          invalid = hypot(x-o.position(1),y-o.position(2)) < 2.5*o.size;
          while any(invalid)
              count = nnz(invalid);
              x(invalid) = rand(o.rng,count,1)*(o.Xtop-o.Xbot) + o.Xbot;
              y(invalid) = rand(o.rng,count,1)*(o.Ytop-o.Ybot) + o.Ybot;
              invalid = hypot(x-o.position(1),y-o.position(2)) < 2.5*o.size;
          end
      else
          radius = sqrt(rand(o.rng,n,1))*o.maxRadius;
          theta = rand(o.rng,n,1)*2*pi;
          [x,y] = pol2cart(theta,radius);
      end
    end

    function [x,y] = randomPosition(o)
      if isinf(o.maxRadius)
          x = rand(o.rng)*(o.Xtop-o.Xbot) + o.Xbot;
          y = rand(o.rng)*(o.Ytop-o.Ybot) + o.Ybot;
      else
          radius = sqrt(rand(o.rng))*o.maxRadius;
          theta = rand(o.rng)*2*pi;
          [x,y] = pol2cart(theta,radius);
      end
    end

    function group = polarityGroup(~,polarity)
      group = round(polarity) + 2;
      group = min(3,max(1,group));
    end
                
    function moveDots(o)

      % calculate future position
      x_ = o.x + o.dx;
      y_ = o.y + o.dy;

      replaceIdx = [];
      if isinf(o.maxRadius)
          o.x = x_;
          o.y = y_;
          %***** replace 
           iireplace = (o.x > o.Xtop) | (o.x < o.Xbot) | (o.y < o.Ytop) | (o.y > o.Ybot) ; %Leaving Y inverted for now  
           
           centerDist = hypot(o.x-o.position(1), o.y-o.position(2));
           radii = o.centerDecayRadii(:);
           steps = max(1, round(o.centerDecaySteps(:)));
           if isempty(radii)
               radii = 0.5;
           end
           if isempty(steps)
               steps = 1;
           end
           if numel(steps) < numel(radii)
               steps(end+1:numel(radii),1) = steps(end);
           end

           if o.centerDecay
               indcloseall = [];
               for ii = 1:numel(radii)
                   indclose = find(centerDist < radii(ii)*o.size);
                   indcloseall = [indcloseall; indclose(1:steps(ii):end)];
               end
               replaceIdx = union(find(iireplace),unique(indcloseall));
           else
               tooclose = centerDist < radii(1)*o.size;
               indclose1 = find(tooclose);
               replaceIdx = union(find(iireplace),indclose1);
           end

          %***********
      else
         o.x = x_;
         o.y = y_;

         r = sqrt(x_.^2 + y_.^2);
         iireplace = find(r > o.maxRadius); % dots that have exited the aperture  
         replaceIdx = iireplace;

      end
      
      expiredIdx = find(o.frameCnt <= 0); % dots that exceeded their lifetime
      replaceIdx = union(replaceIdx,expiredIdx);
      if ~isempty(replaceIdx)
        % Rebuild the spatial grid only once for all replacements this frame.
        o.initDots(replaceIdx);
      end

    end
    
    function drawDots(o)
      % dotType:
      %
      %   0 - square dots (default)
      %   1 - round, anit-aliased dots (fvour performance)
      %   2 - round, anti-aliased dots (favour quality)
      %   3 - round, anti-aliased dots (built-in shader)
      %   4 - square dots (built-in shader)

      % One batched draw call keeps the online rendering cost closest to
      % the legacy implementation. The colour matrix is built before trial.
      drawColours = o.dotColours;
      if size(drawColours,1) == 3
          drawColours = [drawColours;255*ones(1,size(drawColours,2))];
      end
      if o.exactColour
          [oldSource,oldDestination] = Screen('BlendFunction',o.winPtr, ...
              'GL_ONE','GL_ZERO');
          Screen('DrawDots',o.winPtr,[o.x(:),o.y(:)]',o.size, ...
              drawColours,[0,0],o.dotType);
          [usedSource,usedDestination] = Screen('BlendFunction',o.winPtr, ...
              oldSource,oldDestination);
          o.lastBlendFunction = {usedSource,usedDestination};
      else
          Screen('DrawDots',o.winPtr,[o.x(:),o.y(:)]',o.size, ...
              drawColours,[0,0],o.dotType);
      end

    end

    function setCenterDecayProfile(o,profile)
      if isnumeric(profile)
          switch profile
              case 0
                  profile = 'off';
              case 1
                  profile = 'laser';
              case 2
                  profile = 'tdm';
              otherwise
                  error('opticflow:UnknownCenterDecayProfile', ...
                      'Unknown numeric center-decay profile: %g', profile);
          end
      end

      switch lower(char(profile))
          case {'laser','laserdefault'}
              o.centerDecay = true;
              o.centerDecayRadii = [0.5 1.5 2.5 5];
              o.centerDecaySteps = [1 5 15 30];
          case {'tdm','treadmill'}
              o.centerDecay = true;
              o.centerDecayRadii = [0.15 0.25 0.5 1.5];
              o.centerDecaySteps = [1 5 15 30];
          case {'off','none'}
              o.centerDecay = false;
              o.centerDecayRadii = 0.5;
              o.centerDecaySteps = 1;
          otherwise
              error('opticflow:UnknownCenterDecayProfile', ...
                  'Unknown center-decay profile: %s', char(profile));
      end
    end
  end % methods
  
  methods (Static)
    function [xx, yy] = rotate(x,y,th)
      % rotate (x,y) by angle th

      for ii = 1:length(th)
        % calculate rotation matrix
        R = [cos(th(ii)) -sin(th(ii)); ...
             sin(th(ii))  cos(th(ii))];

        tmp = R * [x(ii), y(ii)]';
        xx(ii) = tmp(1,:);
        yy(ii) = tmp(2,:);
      end
    end
  end % methods

end % classdef
