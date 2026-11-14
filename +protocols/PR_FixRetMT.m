classdef PR_FixRetMT < handle
  % Matlab class for running an experimental protocl
  %
  % The class constructor can be called with a range of arguments:
  % TODO: ADD DRIFTING DOTS CARRIER
  % WEDGES FOR MT, FULL SCREEN DOTS, stationary except dots within wedges move
  % Steps, remove bar/wedges code. Not going to be useful for this
  %        replace with full screen expanding dot flow field- with Fix
  %        then generate wedge for carrier, each trial has a different
  %        location. Dots everywhere get updated each frame but on those in
  %        the wedges have a nonzero speed

  %     Change optic flow to set speed?
  %     Don't remove dots between trials????
  
  properties (Access = public) 
       Iti double = 1;            % default Iti duration
       startTime double = 0;      % trial start time
       fixStart double = 0;       % fix acquired time
       itiStart double = 0;       % start of ITI interval
       fixDur double = 0;         % fixation duration
       faceTrial logical = true;  % trial with face to start
       showFix logical = true;    % trial start with fixation
       flashCounter double = 0;   % counter to flash fixation
       rewardCount double = 0;    % counter for reward drops
       trialCount double = 0;     % counter for trials
       RunFixBreakSound double = 0;       % variable to initiate fix break sound (only once)
       NeverBreakSoundTwice double = 0;   % other variable for fix break sound
       BlackFixation double = 6;          % frame to see black fixation, before reward
       ImCounter double = 1;             % counter for Gabor flashing stimuli
       updateEveryNFrames double = 12
       ImSequence = 1:60
       GazeContingent logical = false
  end
      
  properties (Access = private)
    winPtr; % ptb window
    state double = 0;      % state counter
    error double = 0;      % error state in trial
    %*********
    S;      % copy of Settings struct (loaded per trial start)
    P;      % copy of Params struct (loaded per trial)
    %********* stimulus structs for use
    hProbe;
    Bars;
    ringwedges;

    %Ret mapping envelope
    radiilist;
    anglist;
    radiilist_full;
    anglist_full;
    RetRad;
    RetAng;
    
    Faces;             % object that stores face images for use
    hFix;              % object for a fixation point
    fixbreak_sound;    % audio of fix break sound
    fixbreak_sound_fs; % sampling rate of sound
    targOri = 1;       % current orientation of target probe
    oriNum = 1;        % number of oriented textures to draw from for probe
    orilist = [0 90];
    barwidth = .01;
    noiseStim = 0;     % which noise stim (if long term duration)
    hNoise = [];       % random flashing background grating
    noiseNum = 1;      % number of oriented textures
    spatoris = [];     % list of tested orientations
    spatfreqs = [];    % list of tested spatial freqs
    trialsList = [];
    %*********
    noisetype = 0;     % type of background noise stimulus
    NoiseHistory = []; % list of noise frames over trial and their times
    FrameCount = 0;    % count noise frames
    ProbeHistory = []; % list of history for probe objects
    StartTex = [];
    Reverse = [];
    RetHistory = [];
    TexHistory = [];
    PFrameCount = 0;   % count probe frames (should be same as noise for now)
    nFramesPerStim = 30; 
    MaxFrame = (120*20); % twenty second maximum
    TrialDur = 0;      % store internally the trial duration (make less than 20)
    %****************
    PosList = [];      % will be x,y positions of stimuli
    MovList = [];      % speed vector if a moving item
    FixTime = 0;      % will be duration item is fixated
    MovStep = 0;       % vector amplitude motion step if moving probe
    %*******
    FixCount = 0;      % count fixation of probe events
    FixHit = [];       % list of positions where probe hits occured
    FixMax = 20;        % maximum fixations in any trial
    %**** Photodiode flash timing
    Flashtime = [];
    FlashOutTimings = [];
    %**********************************
    D = struct;        % store PR data for end plot stats
  end
  
  methods (Access = public)
    function o = PR_FixRetMT(winPtr)
      o.winPtr = winPtr;     
      o.trialsList = [];  % should be set by generate call
    end
    
    function state = get_state(o)
        state = o.state;
    end
    
    function initFunc(o,S,P)
        %********** Set-up for trial indexing (required) 
        o.trialCount=0;
       %o.trialsList = [];  % empty for this protocol
       %generate_trialsList(o,S,P) % This gets called in the main marmoview
       %run loop
       %**********
      
       %Fill in some hidden parameters
       P.fixRadius      = P.Radius;
       P.faceradius     = P.Radius;
       P.proberadius    = P.Radius;       
       
       %******* init Noise History with MaxDuration **************
       o.ProbeHistory = zeros(o.MaxFrame,6);  % x,y,ori,fixated,texture, sparsity
       
       %******* init reward face for correct trials
       o.Faces = stimuli.gaussimages(o.winPtr,'bkgd',S.bgColour,'gray',false);   % color images
       o.Faces.loadimages('./SupportData/MarmosetFaceLibrary.mat');
       o.Faces.position = [0,0]*S.pixPerDeg + S.centerPix;
       o.Faces.radius = round(P.faceradius*S.pixPerDeg);
       o.Faces.imagenum = 1;  % start first face
       o.Faces.transparency = -1;  % blend into background
       
       o.FixTime = 0;
       o.oriNum = P.orinum;
%        o.prefori= P.prefori;
       o.targOri = 1;
       

        %******* create fixation point ****************
        o.hFix = stimuli.fixation(o.winPtr);   % fixation stimulus
        % set fixation point properties
        sz = P.fixPointRadius*S.pixPerDeg;
        o.hFix.cSize = sz;
        o.hFix.sSize = 2*sz;
        o.hFix.cColour = ones(1,3); % black
        o.hFix.sColour = repmat(255,1,3); % white
        o.hFix.position = [0,0]*S.pixPerDeg + S.centerPix;
        o.hFix.updateTextures();
        %**********************************
   
        %******** store history of flashed gratings
        o.NoiseHistory = nan(o.MaxFrame,5);   %time, x, y, phase, texnum
        
        %********** load in a fixation error sound ************
        [y,fs] = audioread(['SupportData',filesep,'gunshot_sound.wav']);
        y = y(1:floor(size(y,1)/3),:);  % shorten it, very long sound
        o.fixbreak_sound = y;
        o.fixbreak_sound_fs = fs;
        %*********************


        %********* parameters for optic flow ***********
        o.hProbe = stimuli.opticflow(o.winPtr); % optic flow

        %Optic flow
        o.hProbe(1).position = [(S.centerPix(1) + round(P.xDeg*S.pixPerDeg)),(S.centerPix(2) - round(P.yDeg*S.pixPerDeg))];
        o.hProbe(1).f= 0.100; %0.01
        o.hProbe(1).depth= 10; %2
        o.hProbe(1).size= (S.pixPerDeg/P.cpd)/2; %half a cycle (in pixels)
        o.hProbe(1).vxyz= [0 0 .25];
        o.hProbe(1).nDots= 500;
        o.hProbe(1).transparent= 0.5000;
        o.hProbe(1).pixperdeg= S.pixPerDeg;
        o.hProbe(1).screenRect= S.screenRect;
        o.hProbe(1).colour= 128+127.*(sign(rand(o.hProbe(1).nDots,1)-0.5).*[1 1 1])';
        o.hProbe(1).bkgd= 127;
        o.hProbe(1).maxRadius= inf;
        o.hProbe(1).lifetime= 120;
        o.hProbe(1).centerDecay= false;
        if isfield(P,'centerDecayProfile')
            o.hProbe(1).setCenterDecayProfile(P.centerDecayProfile);
        end
        if isfield(P,'centerDecay')
            o.hProbe(1).centerDecay = logical(P.centerDecay);
        end
        if isfield(P,'centerDecayRadii')
            o.hProbe(1).centerDecayRadii = P.centerDecayRadii;
        end
        if isfield(P,'centerDecaySteps')
            o.hProbe(1).centerDecaySteps = P.centerDecaySteps;
        end
        o.hProbe(1).Xtop=  S.screenRect(3);
        o.hProbe(1).Xbot=  S.screenRect(1);
        o.hProbe(1).Ytop=  S.screenRect(2);
        o.hProbe(1).Ybot=  S.screenRect(4);

        %Begins the dots before the trial begins
        o.hProbe(1).beforeTrial();
        %%
    end
   
    function updatedots(o,~,~,~)
        % already done, o.FrameCount = o.FrameCount + 1;   

        % Update positions -> optic flow
%         Ax = [o.hProbe.fs o.hProbe.zs o.hProbe.x-o.hProbe.position(1)];
%         Ay = [o.hProbe.zs o.hProbe.fs o.hProbe.y-o.hProbe.position(2)];
%         o.hProbe.dx = Ax*o.hProbe.vxyz'./o.hProbe.z;
%         o.hProbe.dy = Ay*o.hProbe.vxyz'./o.hProbe.z;
    
        % Polar from center (direction to move)
        pang=atan2((o.hProbe.y-o.hProbe.position(2)),(o.hProbe.x-o.hProbe.position(1)));
        speed=8; %REPLACE WITH PARAM
        o.hProbe.dx = speed.*cos(pang);
        o.hProbe.dy = speed.*sin(pang);
    
       

        %set size of envelope
        Wedgerad=mode(diff(o.radiilist));
        Wedgeang=mode(diff(o.anglist));

        dotx=(o.hProbe.x-o.S.centerPix(1))/o.S.pixPerDeg; % x coords (pixels) (nDots, 1)
        doty=(o.hProbe.y-o.S.centerPix(2))/o.S.pixPerDeg; % y coords (pixels)
        [dotTH,dotR] = cart2pol(dotx,doty);
        %east is 0, south is pi/2, north is p/2, west is +-pi
        dotTH=180*dotTH/pi + 90; dotTH(dotTH<0)=360+dotTH(dotTH<0);
        %north is 0 and 360, east is 90, south is 180, west is 270
        lowerRad=o.RetRad-Wedgerad/2;
        upperRad=o.RetRad+Wedgerad/2;

        lowerAng=o.RetAng-Wedgeang/2; lowerAng(lowerAng<0)=360+lowerAng(lowerAng<0);
        upperAng=o.RetAng+Wedgeang/2; upperAng(upperAng<0)=360+upperAng(upperAng<0);
        
        if lowerAng<upperAng
            keepdots=(dotTH>lowerAng)&(dotTH<upperAng)&(dotR>lowerRad)&(dotR<upperRad);
        else
            keepdots=((dotTH>lowerAng)|(dotTH<upperAng))&(dotR>lowerRad)&(dotR<upperRad);
        end
        freezedots=~keepdots;


        %Remove dx dy from out of wedge
        % If we set the speed zero at start of trial, rather than each
        % frame it will probably be more efficient? No, dots would move out
        % of window. Note we need to respawn some in too
                % Here goes the wedges envelope
                % Check dots positions
    
        o.hProbe.dx(freezedots)=0; % 
        o.hProbe.dy(freezedots)=0; % 

         % decrement frame counters
        o.hProbe.frameCnt(~freezedots) = o.hProbe.frameCnt(~freezedots) - 1;
    

      % calculate future position
      x_ = o.hProbe.x(keepdots) + o.hProbe.dx(keepdots);
      y_ = o.hProbe.y(keepdots) + o.hProbe.dy(keepdots);

      %if they exit the aperture, redraw inside
      dotx_=(x_-o.S.centerPix(1))/o.S.pixPerDeg; % x coords (deg) (nDots, 1)
      doty_=(y_-o.S.centerPix(2))/o.S.pixPerDeg; % y coords (deg)
      [dotTH_,dotR_] = cart2pol(dotx_,doty_);
      dotTH_=180*dotTH_/pi + 90;  dotTH_(dotTH_<0)=360+dotTH_(dotTH_<0);

      if lowerAng<upperAng
        outdots=(dotTH_<=lowerAng)|(dotTH_>=upperAng)|(dotR_<=lowerRad)|(dotR_>=upperRad)|(o.hProbe.frameCnt(keepdots)<1); %a subset of keepdots that move out of the aperture
      else
        outdots=((dotTH_<=lowerAng)&(dotTH_>=upperAng))|(dotR_<=lowerRad)|(dotR_>=upperRad)|(o.hProbe.frameCnt(keepdots)<1); %a subset of keepdots that move out of the aperture
      end
      
      % Also check if they go out of bounds
      if isinf(o.hProbe.maxRadius)
          ireplace = (x_ > o.hProbe.Xtop) | (x_ < o.hProbe.Xbot) | (y_ < o.hProbe.Ytop) | (y_ > o.hProbe.Ybot) ; %Leaving Y inverted for now 
      else
          r = sqrt(x_.^2 + y_.^2);
         ireplace = (r > o.hProbe.maxRadius); % dots that have exited the aperture  
      end
      outdots=outdots|ireplace;

      iid_keep=find(keepdots);iid_outdots=iid_keep(outdots);
      nout=numel(iid_outdots);

        %Respawn dots inside wedge
        randang=o.RetAng+1*(rand(nout,1)-0.5)*Wedgeang;

        %Need to check if hitting the edge is possible at current angle, far points at min and max angle
        testmax1_th=o.RetAng-0.5*Wedgeang;
        testmax2_th=o.RetAng+0.5*Wedgeang;
        [testmax1_x,testmax1_y]=pol2cart(pi*(testmax1_th-90)/180,o.RetRad+0.5*Wedgerad); %in degrees
        [testmax2_x,testmax2_y]=pol2cart(pi*(testmax2_th-90)/180,o.RetRad+0.5*Wedgerad); %in degrees

        testmax1_x=testmax1_x*o.S.pixPerDeg + o.S.centerPix(1);
        testmax2_x=testmax2_x*o.S.pixPerDeg + o.S.centerPix(1);
        testmax1_y=testmax1_y*o.S.pixPerDeg + o.S.centerPix(2);
        testmax2_y=testmax2_y*o.S.pixPerDeg + o.S.centerPix(2);

        itest1 = (testmax1_x > o.hProbe.Xtop) | (testmax1_x < o.hProbe.Xbot) | (testmax1_y < o.hProbe.Ytop) | (testmax1_y > o.hProbe.Ybot) ; %Leaving Y inverted for now 
        itest2 = (testmax2_x > o.hProbe.Xtop) | (testmax2_x < o.hProbe.Xbot) | (testmax2_y < o.hProbe.Ytop) | (testmax2_y > o.hProbe.Ybot) ; %Leaving Y inverted for now 
        
        if sum(ireplace)>0||itest1||itest2 %hitting edge of screen, limit rad. 
            maxrad=min([o.hProbe.Xtop-o.hProbe.Xbot o.hProbe.Ybot-o.hProbe.Ytop])/(2*o.S.pixPerDeg); %closest screen border
            minrad=o.RetRad-0.5*Wedgerad;
            randrad = minrad+rand(nout,1).*(maxrad-minrad);
        else
            randrad=o.RetRad+1*(rand(nout,1)-0.5)*Wedgerad;
        end
        [outdotx,outdoty]=pol2cart(pi*(randang-90)/180,randrad); %in degrees
        o.hProbe.x(iid_outdots)=outdotx*o.S.pixPerDeg+o.S.centerPix(1);
        o.hProbe.y(iid_outdots)=outdoty*o.S.pixPerDeg+o.S.centerPix(2);
        

        %don't move these dots on first frame
        o.hProbe.dx(iid_outdots)=0; % 
        o.hProbe.dy(iid_outdots)=0; % 

        %give new dots a new lifetime
        o.hProbe.frameCnt(iid_outdots) = o.hProbe.lifetime; % default: Inf

        o.hProbe.moveDots();
        o.hProbe.beforeFrame(); %draws dots

         % NOTE: store screen time in "continue_run_trial" after flip, time
         % when stimuli actually appears
        o.ProbeHistory(o.FrameCount,2) = o.hProbe.position(1);  
        o.ProbeHistory(o.FrameCount,3) = o.hProbe.position(2); 

    end


    function closeFunc(o)
        %o.hProbe.CloseUp();
        o.hFix.CloseUp();
    end
   
    function generate_trialsList(o,S,P)
           % nothing for this protocol
           % Radii and angles
           
           o.radiilist=3:3:9;
           o.anglist=0:45:315;
           nang=length(o.anglist);
           nrad=length(o.radiilist);
           o.radiilist_full=repmat(o.radiilist,nang,1)';
           o.anglist_full=repmat(o.anglist,nrad,1);

           comb=nang*nrad;%length(o.radiilist)*length(o.anglist);
           %Allocate and pseudorandomise trials
           reps=ceil(S.finish/comb);
           
            disp(['For maximum full repeats stop at trial: ' num2str(comb*floor(S.finish/comb))]);

           List=nan(comb,reps);
           for ii=1:reps
                List(:,ii) = randperm(comb);
           end
           o.trialsList=List(:);
    end
    
    function P = next_trial(o,S,P)
          %********************
          o.S = S;
          o.P = P;      
          o.FrameCount = 0;   % for noise history
          o.trialCount = o.trialCount+1;

          % Initialising here generates a new optic flow stimulus per trial, prohibiting
          % keeping the dots onscreen between trials. Moved to init
            

            o.RetRad= o.radiilist_full(o.trialsList(o.trialCount));
            o.RetAng= o.anglist_full(o.trialsList(o.trialCount));

%           o.StartTex=randi(o.ringwedges.Ntex,1);
%           o.Reverse=round(rand(o.ringwedges.rng,1)+eps);
% 

          %*******************
        
          %%%% Trial control -- Update certain parameters depending on run type %%%%%
          switch o.P.runType
            case 1  % Staircasing
                % If correct, small increment in fixation duration
                if ~o.error
                    P.fixMin = P.fixMin + S.staircase.up(1);
                    P.fixRan = P.fixRan + S.staircase.up(2);
                    % cannot exceed limit
                    P.fixMin = min([P.fixMin S.staircase.durLims(3)]);
                    P.fixRan = min([P.fixRan S.staircase.durLims(4)]);
                % If entered fixationand failed to maintain it, large reduction in
                % fixation duration
                elseif o.error == 2
                    P.fixMin = P.fixMin - S.staircase.down(1);
                    P.fixRan = P.fixRan - S.staircase.down(2);
                    % cannot exceed limit
                    P.fixMin = max([P.fixMin S.staircase.durLims(1)]);
                    P.fixRan = max([P.fixRan S.staircase.durLims(2)]);
                end
          end
          %*************************************
          
          % Set up fixation duration
          o.fixDur = P.fixMin + ceil(1000*P.fixRan*rand)/1000;

          % Reward schedule is automated based on fix duration for staircasing
          if S.runType
              P.rewardNumber = find(o.fixDur > S.staircase.rewardSchedule,1,'last');
          end

          % Select a face from image set to show at center
          o.Faces.imagenum = randi(length(o.Faces.tex));  % pick any at random
           % o.reset_probe_location_and_texture(1)

          if rand < P.faceTrialFraction
              o.faceTrial = true;
          else
              o.faceTrial = false;
          end
    end
    
    function [FP,TS] = prep_run_trial(o)
        
          %********VARIABLES USED IN RUNNING TRIAL LOGISTICS
          % showFix is a flag to check whether to show the fixation spot or not while
          % it is flashing in state 0
          o.showFix = true;
          % flashCounter counts the frames to switch ShowFix off and on
          o.flashCounter = 0;
          % rewardCount counts the number of juice pulses, 1 delivered per frame
          o.rewardCount = 0;
          %****** deliver sound on fix breaks
          o.RunFixBreakSound =0;
          o.NeverBreakSoundTwice = 0;  
          o.BlackFixation = 6;  % frame to see black fixation, before reward
          o.ImCounter = 1;
          % Setup the state
          o.state = 0; % Showing the face
          o.error = 0; % Start with error as 0
          o.Iti = o.P.iti;   % set ITI interval from P struct stored in trial


          o.nFramesPerStim=o.P.nFramesPerStim;

          %******* Plot States Struct (show fix in blue for eye trace)
          % any special plotting of states, 
          % FP(1).states = 1:2; FP(1).col = 'b';
          % would show states 1,2 in blue for eye trace
          FP(1).states = 1;  %before fixation
          FP(1).col = 'k';
          FP(2).states = 2;  % fixation held
          FP(2).col = 'b';
          %******* set which states are TimeSensitive, if [] then none
          TS = 2;  % state 2 is senstive, during Gabor flashing
          %********
          o.startTime = GetSecs;
    end
    
    function keepgoing = continue_run_trial(o,screenTime)
        keepgoing = 0;
        if (o.state < 4)
            keepgoing = 1;
        end
        %****** store the last screen flip for noise history
        if (o.FrameCount)
           o.NoiseHistory(o.FrameCount,1) = screenTime;
        end
        %*******************    
    end
   
    %******************** THIS IS THE BIG FUNCTION *************
    function drop = state_and_screen_update(o,currentTime,x,y,varargin)  
        drop = 0;
        outputs = {};
        if length(varargin)>1
            outputs = varargin{2};
        end
        %******* THIS PART CHANGES WITH EACH PROTOCOL ****************

        %%%%% STATE 0 -- GET INTO FIXATION WINDOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % If eye travels within the fixation window, move to state 1
        if o.state == 0 && norm([x y]) < o.P.fixWinRadius
           o.state = 1; % Move to fixation grace
           o.fixStart = GetSecs;
        end
        % Trial expires if not started within the start duration
        if o.state == 0 && currentTime > o.startTime + o.P.startDur
           o.state = 3; % Move to iti -- inter-trial interval
           o.error = 1; % Error 1 is failure to initiate
           o.itiStart = GetSecs;
        end
    
        %%%%% STATE 1 -- GRACE PERIOD TO BE IN FIXATION WINDOW %%%%%%%%%%%%%%%%
        % A grace period is given before the eye must remain in fixation
        if o.state == 1 && currentTime > o.fixStart + o.P.fixGrace
            o.state = 2; % Move to hold fixation
        end
    
        %%%%% STATE 2 -- HOLD FIXATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if o.state == 2    % show stimuli while fixation is maintained
            o.FrameCount = o.FrameCount + 1;
            o.PFrameCount = o.FrameCount;
%%
            if mod(o.FrameCount, o.updateEveryNFrames)==0
                o.ImCounter = o.ImCounter + 1;
                if (o.ImCounter > numel(o.ImSequence))
                    o.ImCounter = 1;
                end
%                 o.Faces.imagenum = o.ImSequence(o.ImCounter);
            end
 
            o.NoiseHistory(o.FrameCount,:) = [NaN,o.hProbe.position,o.RetRad,o.RetAng];%[NaN,o.hProbe.position,o.ringwedges.phase,o.ringwedges.texnum];
            %*********************
        end
    
        % If fixation is held for the fixation duration, then reward
        if o.state == 2 && currentTime > o.fixStart + o.fixDur
            o.state = 3; % Move to iti -- inter-trial interval
            o.itiStart = GetSecs;
        end

        % Eye must remain in the fixation window
        if o.state == 2 && norm([x y]) > o.P.fixWinRadius
            o.state = 3; % Move to iti -- inter-trial interval
            o.error = 2; % Error 2 is failure to hold fixation
            o.itiStart = GetSecs;
        end
    
        %%%%% STATE 3 -- INTER-TRIAL INTERVAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Deliver rewards
        if o.state == 3 
           if ~o.error && o.rewardCount < o.P.rewardNumber
             if currentTime > o.itiStart + 0.2*o.rewardCount % deliver in 200 ms increments
               o.rewardCount = o.rewardCount + 1;
               drop = 1;   % this is where you return with instruction to give reward
             end
           else
             if currentTime > o.itiStart + 0.2   % enough time to flash fix break 
               o.state = 4; 
               if o.error 
                 o.Iti = o.P.iti + o.P.timeOut;
               end
             end
           end
        end
    
        % FIRST DOT DRAW (STATIC)
        if o.FrameCount==0
%             o.hProbe.afterFrame();
            o.hProbe.dx = zeros(size(o.hProbe.dx));
            o.hProbe.dy = zeros(size(o.hProbe.dy));
            %o.hProbe.frameCnt = o.hProbe.frameCnt - 1;
            %o.hProbe.moveDots();
            o.hProbe.beforeFrame(); %draws dots
        end


        % STATE SPECIFIC DRAWS
        switch o.state
            case 0
                %Still draws dots!
                % o.hProbe.afterFrame();
                o.hProbe.dx = zeros(size(o.hProbe.dx));
                o.hProbe.dy = zeros(size(o.hProbe.dy));
                %o.hProbe.frameCnt = o.hProbe.frameCnt - 1;
                %o.hProbe.moveDots();
                o.hProbe.beforeFrame(); %draws dots

                if o.showFix
                    %if ~o.faceTrial
                         o.hFix.beforeFrame(1);
                    %else
                    %     o.Faces.beforeFrame();  %draw an image at random
                    %end
                end
                o.flashCounter = mod(o.flashCounter+1,o.P.flashFrameLength);
                if o.flashCounter == 0
                    o.showFix = ~o.showFix;
                    if o.showFix && o.faceTrial
                        if rand < o.P.faceTrialFraction
                            o.faceTrial = true;
                        end
                    else
                        o.faceTrial = false;
                    end
                end

                if o.FrameCount>0
                    %State0, grace period saving
                    o.ProbeHistory(o.FrameCount,1) = NaN;
                    o.ProbeHistory(o.FrameCount,2) = NaN;
                    o.ProbeHistory(o.FrameCount,3) = 0;  % intermediate at drop          
                    o.ProbeHistory(o.FrameCount,5) = NaN;
                    
                    o.BarHistory{o.FrameCount} = NaN;
                end

            case 1
                %Still draws dots!
                % o.hProbe.afterFrame();
                o.hProbe.dx = zeros(size(o.hProbe.dx));
                o.hProbe.dy = zeros(size(o.hProbe.dy));
                %o.hProbe.frameCnt = o.hProbe.frameCnt - 1;
                %o.hProbe.moveDots();
                o.hProbe.beforeFrame(); %draws dots


                o.hFix.beforeFrame(1);
                if o.FrameCount>0
                    %State1, fixation period saving
                    o.ProbeHistory(o.FrameCount,1) = o.hFix.position(1);
                    o.ProbeHistory(o.FrameCount,2) = o.hFix.position(2);
                    o.ProbeHistory(o.FrameCount,3) = -2;  % indicate fixation          
                    o.ProbeHistory(o.FrameCount,5) = NaN;
                    
                    o.BarHistory{o.FrameCount} = NaN;
                end

            case 2    % Displaying stim
                
                %Update to the next position of the probe
                o.updatedots(x,y,currentTime)

            case 3
                %Still draws dots!
                % o.hProbe.afterFrame();
                o.hProbe.dx = zeros(size(o.hProbe.dx));
                o.hProbe.dy = zeros(size(o.hProbe.dy));
                %o.hProbe.frameCnt = o.hProbe.frameCnt - 1;
                %o.hProbe.moveDots();
                o.hProbe.beforeFrame(); %draws dots
                if ~o.error
                    if (o.BlackFixation)
                       o.hFix.beforeFrame(3);
                       o.BlackFixation = o.BlackFixation - 1; 
%                     else
%                       o.Faces.beforeFrame(); 
%                       if o.FrameCount>0
%                           o.ProbeHistory(o.FrameCount,1) = o.Faces.position(1);  % 
%                           o.ProbeHistory(o.FrameCount,2) = o.Faces.position(2);
%                           o.ProbeHistory(o.FrameCount,3) = -1;   %indicates face
%                           o.ProbeHistory(o.FrameCount,5) = o.Faces.imagenum; %face texture number
%             
%                           o.RetHistory{o.FrameCount} = NaN;
%                       end
                    end
                end
                if (o.error == 2)  % fixation break
                    o.hFix.beforeFrame(2);
                    o.RunFixBreakSound = 1;
                    if o.FrameCount>0
                        %State1, fixation period saving
                        o.ProbeHistory(o.FrameCount,1) = o.hFix.position(1);
                        o.ProbeHistory(o.FrameCount,2) = o.hFix.position(2);
                        o.ProbeHistory(o.FrameCount,3) = -2;  % indicate fixation          
                        o.ProbeHistory(o.FrameCount,5) = NaN;
                        
                        o.RetHistory{o.FrameCount} = NaN;
                    end
                end
            case 4
                %Still draw dots! Even after trial!!
                % o.hProbe.afterFrame();
                o.hProbe.dx = zeros(size(o.hProbe.dx));
                o.hProbe.dy = zeros(size(o.hProbe.dy));
                %o.hProbe.frameCnt = o.hProbe.frameCnt - 1;
                %o.hProbe.moveDots();
                o.hProbe.beforeFrame(); %draws dots

                if isfield(o.S,'photodiode')
                    Screen('FillRect',o.winPtr,o.S.photodiode.init,o.S.photodiode.rect)
                end

        end

        %******** if sound, do here
        if (o.RunFixBreakSound == 1) && (o.NeverBreakSoundTwice == 0)  
           sound(o.fixbreak_sound,o.fixbreak_sound_fs);
           o.NeverBreakSoundTwice = 1;
        end
        %**************************************************************

        [o.Flashtime,o.FlashOutTimings] = marmoview.updatePhotodiode( ...
            o.winPtr,o.S,outputs,o.PFrameCount,currentTime,o.Flashtime,o.FlashOutTimings);
    end
    
    function Iti = end_run_trial(o)
        Iti = o.Iti - (GetSecs - o.itiStart); % returns generic Iti interval
    end
    
    function plot_trace(o,handles)
        %********* append other things eye trace plots if you desire
        h = handles.EyeTrace;
        set(h,'NextPlot','Replace');
        eyeRad = handles.eyeTraceRadius;
        % Fixation window
        r = o.P.fixWinRadius;
        fixX = o.P.xDeg;
        fixY = o.P.yDeg;
        plot(h,fixX+r*cos(0:.01:1*2*pi),fixY+r*sin(0:.01:1*2*pi),'--k');
        axis(h,[-eyeRad eyeRad -eyeRad eyeRad]);
        set(h,'NextPlot','Add');
    end
    
    function PR = end_plots(o,P,A)   %update D struct if passing back info
        
        %************* STORE DATA to PR
        PR = struct;
        PR.error = o.error;
        PR.fixDur = o.fixDur;
        PR.x = P.xDeg;
        PR.y = P.yDeg;
        %******* this is also where you store Gabor Flash Info
        if o.FrameCount == 0
            PR.NoiseHistory = [];
            PR.ProbeHistory = [];
            PR.RetHistory = [];
            %PR.TexHistory = [];
        else
            PR.NoiseHistory = o.NoiseHistory(1:o.FrameCount,:);
            PR.ProbeHistory = o.ProbeHistory(1:o.FrameCount,:);
            PR.RetHistory = o.RetHistory;%{1:o.FrameCount};
            %PR.TexHistory= o.TexHistory(1:o.FrameCount,:,:);
        end
    
        %%%% Record some data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        o.D.error(A.j) = o.error;
        o.D.x(A.j) = P.xDeg;
        o.D.y(A.j) = P.yDeg;
        o.D.fixDur(A.j) = o.fixDur;

        %Photodiode
        PR.Flashtime = o.Flashtime;
        PR.FlashOutTimings = o.FlashOutTimings;
        
        %%%% Plot results %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Dataplot 1, errors
        errors = [0 1 2; sum(o.D.error==0) sum(o.D.error==1) sum(o.D.error==2)];
        bar(A.DataPlot1,errors(1,:),errors(2,:));
        title(A.DataPlot1,'Errors');
        ylabel(A.DataPlot1,'Count');
        %set(A.DataPlot1,'XLim',[-.75 errors(1,end)+.75]);
        A.DataPlot1.XLim = [-.75 errors(1,end)+.75];
        %% show the number - 2016-05-05 - Shaun L. Cloherty <s.cloherty@ieee.org> 
        x = errors(1,:);
        y = 0.15*max(A.DataPlot1.YLim);

        h = [];
        for ii = 1:size(errors,2)
%           axes(A.DataPlot1);
          h(ii) = text(A.DataPlot1,x(ii),y,sprintf('%i',errors(2,ii)),'HorizontalAlignment','Center');
          if errors(2,ii) > 2*y
            set(h(ii),'Color','w');
          end
        end
        %%

        % Dataplot 2, wait time histogram
        if any(o.D.error==0)
            hist(A.DataPlot2,o.D.fixDur(o.D.error==0));
        end
        % title(A.DataPlot2,'Successful Trials');
        % show the numbers - 2016-05-06 - Shaun L. Cloherty <s.cloherty@ieee.org> 
        title(A.DataPlot2,sprintf('%.2fs %.2fs',median(o.D.fixDur(o.D.error==0)),max(o.D.fixDur(o.D.error==0))));
        ylabel(A.DataPlot2,'Count');
        xlabel(A.DataPlot2,'Time');

    end
    
  end % methods
    
end % classdef
