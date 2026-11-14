classdef PR_FixRetRF < handle
  % Matlab class for running an experimental protocl
  %
  % The class constructor can be called with a range of arguments:
  %
  
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
    Bars;
    ringwedges;
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
    function o = PR_FixRetRF(winPtr)
      o.winPtr = winPtr;     
      o.trialsList = [];  % should be set by generate call
    end
    
    function state = get_state(o)
        state = o.state;
    end
    
    function initFunc(o,S,P)
        %********** Set-up for trial indexing (required) 
       cors = [0,4];  % count these errors as correct trials
       reps = [1,2];  % count these errors like aborts, repeat
       o.trialsList = [];  % empty for this protocol
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
       
        
       %Would probably be better to set up these three conditions in the
%        %trialList 
%        %***** create a set of 1D noise textures to move around as probe
%        o.Bars = stimuli.barRFs(o.winPtr,'bkgd',S.bgColour,'gray',false); % 1D noise as probe
%        %o.Bars.prctgray = 33.33;
%        o.Bars.sparsity = 0;
%        o.Bars.contrast = P.probecon;
%        o.Bars.texnum   = 1;
%        o.Bars.barwidth  = round(P.barwidth*S.pixPerDeg);
%        o.Bars.pxradius   = round(P.proberadius*S.pixPerDeg);
%        %o.Bars.prefori   = P.prefori;
%        o.Bars.pixPerDeg = S.pixPerDeg;
%        
%        o.Bars.makeTex();
%        o.Bars.position = [0,0]*S.pixPerDeg + S.centerPix;
       
  
      
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


        %********* parameters for wedges ***********
        %Just get wedges working
        o.ringwedges=stimuli.ringwedges(o.winPtr);%,'bkgd',S.bgColour,'gray',false);
       o.ringwedges.stim='wedge';
       %o.ringwedges.wedgeWidth=1;
       %o.ringwedges.nAng=1;
       %o.ringwedges.innerRad=0.1;
       %o.ringwedges.stimSize=5;

       %o.ringwedges.stimCtr=[0,0];

       %o.ringwedges.pos=[0,0];
       %o.ringwedges.motionSteps=5;
       %o.ringwedges.nRad=5;
       %o.ringwedges.period =1;
       %o.ringwedges.tf =2;

       %o.ringwedges.srcRect=S.screenRect;
       %o.ringwedges.destRect=S.screenRect;
       
       o.ringwedges.sparsity = 0;
       o.ringwedges.contrast = 80;
       o.ringwedges.texnum   = 1;
       o.ringwedges.barwidth  = round(2*S.pixPerDeg);
       o.ringwedges.pxradius   = round(P.proberadius*S.pixPerDeg);
       %o.ringwedges.prefori   = P.prefori;
       o.ringwedges.pixPerDeg = S.pixPerDeg;
       o.ringwedges.displayctr=S.centerPix;

       %TODO, need to move these to settings
        %Add phase min and max, number of increments

        %Parameters for the polar checkboard carrier

        %Parameters for the moving envelope


        % %Intervals for increments of phase of polar angle of center of wedges
        phinc       = pi/8;%pi/24;
        wedgeWidth  = phinc;%1.5*phinc;
        %Angular width of wedges is o.wedgeWidth/o.nAng;
        fixRadius = .5;
        
        %% Some of the following can just be left as defaults in ringwedges
        % Starting phases, clockwise from leftward=0, pi/2 (5pi/2) = up, pi= right, 3*pi/2 down
            subwedperwed=2;% subwedges are offcentered by .5
            
            o.ringwedges.wedgeWidth = subwedperwed;       %number of sub-wedges in a wedge  
            o.ringwedges.nAng = subwedperwed*2*pi/(wedgeWidth);%42;%12;        % number of sub-wedges in a circle *2    
           
            %o.ringwedges.stimSize = 20; % Radius in visual angle
            o.ringwedges.innerRad = fixRadius; 
            o.ringwedges.nRad = 12;%24;            % number of sub-rings in a circle * 2
            o.ringwedges.nBar = 5;             % number of bars in the square * 2
               
            o.ringwedges.ringWidth = 1;        %number of sub-rings in a ring (has to be odd)
            o.ringwedges.barWidth = .8;
            o.ringwedges.fixSize = 10;         %fixation point size
            o.ringwedges.junkFrames = 8;             %junk before stimulus in seconds
            o.ringwedges.meriThick = 1/10;     %what proportion of circle is a wedge for the meridian 
            o.ringwedges.meriStart= 'horizontal'; %which to start with: horizontal or vertical
            o.ringwedges.motionSteps = 8;

            %Bottom left quadrant, little bit of overlap on vertical
            %meridian
            o.ringwedges.minphase = pi/2-pi/12;
            o.ringwedges.maxphase = pi - pi/12;

            %Envelope
            switch o.ringwedges.stim
                case 'full-field'
                    o.ringwedges.tf = 8;               %Hz
                    o.ringwedges.stimPeriod = 1.5;
                    o.ringwedges.period = 30; % 24 sec (32 frames at .75 s TR)
                    o.ringwedges.nCycles = 6; % 24 x 6 = 180 (3 min) 240 frames at .75 s TR
                case 'bar'
                    o.ringwedges.tf = 12;               %Hz
                    o.ringwedges.period = 15;          %seconds in entire cycle as in both orientations
                    o.ringwedges.nCycles = size(o.ringwedges.orientationSequences,1);%11; % 8 orientations and 4 blanks 15x12 = 180 (3 min) 240 frames at .75 s TR
                otherwise
                    o.ringwedges.tf = 8;               %Hz
                    o.ringwedges.period = 15;%100          %seconds in entire cycle as in both orientations
                    o.ringwedges.nCycles = 1; % 18x12 = 216 (3.6 min) 288 volumes at .75 s TR
            end
            
      
            switch o.ringwedges.stim
                case 'ring'
                    o.ringwedges.startPhase = .5*o.ringwedges.ringWidth/o.ringwedges.nRad;
                case 'wedge'
                    o.ringwedges.startPhase = 0;%.25*pi;%.25; %.5*o.ringwedges.wedgeWidth/o.ringwedges.nAng; %.25 - 
                case 'meridian' 
                    if o.ringwedges.meriStart=='horizontal' %#ok<STCMP>
                        o.ringwedges.startPhase = .5;
                    else
                        o.ringwedges.startPhase = 0;
                    end
                otherwise
                    o.ringwedges.nOrientations = 8;
                    o.ringwedges.startPhase = 0;
            end
            
        
            o.ringwedges.pos = [0 0]';
            o.ringwedges.stimCtr = [0 0 0];[960, 540, 0]; 
            ncopies = 1;
            o.ringwedges.isi = 0; % blank interstimulus interval between each matrix module
   
            
            %Initialise but should be really be updated in trialprep 
       


            %o.ringwedges.startPhase=0;
            %o.ringwedges.Reverse=0;
           o.ringwedges.makeTex();
           o.ringwedges.position = [0,0]*S.pixPerDeg + S.centerPix;
            %%
    end
   
    function closeFunc(o)
        o.ringwedges.CloseUp();
        o.hFix.CloseUp();
    end
   
    function generate_trialsList(o,S,P)
           % nothing for this protocol
    end
    
    function P = next_trial(o,S,P)
          %********************
          o.S = S;
          o.P = P;      
          o.FrameCount = 0;   % for noise history

          o.StartTex=randi(o.ringwedges.Ntex,1);
          o.Reverse=round(rand(o.ringwedges.rng,1)+eps);
% 
%           %TODO, at beginning of trial
%           %Initialise random startphase, increments
%           phase_step= randi(o.ringwedges.rng, o.ringwedges.Ntex)./o.ringwedges.Ntex;
%           o.ringwedges.startTex=o.ringwedges.minphase+ ...
%               (o.ringwedges.maxphase-o.ringwedges.minphase)*phase_step;
%           %Randomise direction for motion (CW/CCW)
%           Reverse=round(rand(o.ringwedges.rng,1)+eps);
%           o.ringwedges.reverse=reverse;

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
        if o.state == 2    % show flashing stimuli at random points each frame
            %***pick a random screen location but not overlapping fixation
            ampo = o.P.gabMinRadius + (o.P.gabMaxRadius-o.P.gabMinRadius)*rand;
            ango = rand*2*pi;
            dx = cos(ango)*ampo;
            dy = sin(ango)*ampo;
            cX = o.S.centerPix(1)+ round( o.S.pixPerDeg * dx);
            cY = o.S.centerPix(2)+ round( o.S.pixPerDeg * dy);   %
            %****** update one of the Gabor's locations
            %****** store starting locations, set time as NaN
            o.FrameCount = o.FrameCount + 1;
            o.PFrameCount = o.FrameCount;

%             %%  %updating bars
%             kk = ~mod(o.PFrameCount, o.nFramesPerStim);
%             
%             if isempty(o.Bars.texnum)
%                 o.Bars.texnum  = randi(o.Bars.rng, o.Bars.Ntex);
%                 o.Bars.orinum  = randi(o.Bars.rng, length(o.P.orilist));
%                 o.Bars.prefori = o.P.prefori(o.Bars.orinum);
%             elseif kk %update
%                 o.Bars.texnum  = randi(o.Bars.rng, o.Bars.Ntex);  %o.StartTex + kk;%o.Bars.texnum +1; %randi(o.Bars.rng, o.Bars.Ntex);  
%                 o.Bars.orinum  = randi(o.Bars.rng, length(o.P.orilist));
%                 o.Bars.prefori = o.P.orilist(o.Bars.orinum);
%             end
% 
%             if o.Bars.texnum>o.Bars.Ntex
%                 o.Bars.texnum=rem(o.Bars.texnum-1,o.Bars.Ntex)+1;
%                 %o.Bars.texnum=o.Bars.texnum-o.Bars.Ntex;
%             end

            %% Update rings/wedges, just increment???
            kk = ~mod(o.PFrameCount, o.nFramesPerStim);
            
            if isempty(o.ringwedges.texnum)
                o.ringwedges.texnum  = o.startTex;%randi(o.ringwedges.rng, o.ringwedges.Ntex);%
                o.ringwedges.orinum  = randi(o.ringwedges.rng, length(o.P.orilist));
                o.ringwedges.prefori = o.P.prefori(o.ringwedges.orinum);
            elseif kk %update
                if o.Reverse <1 
                   o.ringwedges.texnum  = o.ringwedges.texnum +1; %randi(o.Bars.rng, o.Bars.Ntex);  %o.StartTex + kk;%o.Bars.texnum +1; %randi(o.Bars.rng, o.Bars.Ntex);  
                else
                    o.ringwedges.texnum  = o.ringwedges.texnum -1;
                    if o.ringwedges.texnum<1
                        o.ringwedges.texnum=o.ringwedges.texnum+o.ringwedges.Ntex;
                    end
                end
            end

            if o.ringwedges.texnum>o.ringwedges.Ntex
                o.ringwedges.texnum=rem(o.ringwedges.texnum-1,o.ringwedges.Ntex)+1;
                %o.Bars.texnum=o.Bars.texnum-o.Bars.Ntex;
            end

%%

            if mod(o.FrameCount, o.updateEveryNFrames)==0
                o.ImCounter = o.ImCounter + 1;
                if (o.ImCounter > numel(o.ImSequence))
                    o.ImCounter = 1;
                end
%                 o.Faces.imagenum = o.ImSequence(o.ImCounter);

                %Update bars
                if o.GazeContingent
                    o.ringwedges.position = [o.S.centerPix(1)+x, o.S.centerPix(2)+y];
                end
            end

            
            o.NoiseHistory(o.FrameCount,:) = [NaN,o.ringwedges.position,o.ringwedges.phase,o.ringwedges.texnum];
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
    
        % STATE SPECIFIC DRAWS
        switch o.state
            case 0
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
                

                o.ringwedges.beforeFrame();
                o.hFix.beforeFrame(3); %Continue showing the black fixation dot?

                    if o.FrameCount>0
                    %Params for saving
                      o.ProbeHistory(o.FrameCount,1) = o.ringwedges.position(1);
                       o.ProbeHistory(o.FrameCount,2) = o.ringwedges.position(2);
                       if(~isempty(o.ringwedges.texnum))
                       %o.ProbeHistory(o.FrameCount,3) = o.ringwedges.prefori;
                       o.ProbeHistory(o.FrameCount,5) = o.ringwedges.texnum;
                       end
                       
                       %Save the barcode (could get big, ideally wouldn't need to)
                       %Won't allow for size change during presentation, could
                       %change this to cell but there will be an overhead
                       %o.RetHistory{o.FrameCount} =o.ringwedges.saveline(o.ringwedges.texnum,:);
                       %o.TexHistory(o.PFrameCount,:,:)=o.ringwedges.savesquare(:,:,o.ringwedges.texnum);
                    end

            case 3
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
