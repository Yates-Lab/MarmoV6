classdef PR_FixBarRF < handle
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
    BarHistory = [];
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
    %**********************************
    D = struct;        % store PR data for end plot stats
  end
  
  methods (Access = public)
    function o = PR_FixBarRF(winPtr)
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
       %trialList 
       %***** create a set of 1D noise textures to move around as probe
       o.Bars = stimuli.barRFs(o.winPtr,'bkgd',S.bgColour,'gray',false); % 1D noise as probe
       %o.Bars.prctgray = 33.33;
       o.Bars.sparsity = 0;
       o.Bars.contrast = P.probecon;
       o.Bars.texnum   = 1;
       o.Bars.barwidth  = round(P.barwidth*S.pixPerDeg);
       o.Bars.pxradius   = round(P.proberadius*S.pixPerDeg);
       %o.Bars.prefori   = P.prefori;
       o.Bars.pixPerDeg = S.pixPerDeg;
       
       o.Bars.makeTex();
       o.Bars.position = [0,0]*S.pixPerDeg + S.centerPix;
       
  
      
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
        o.NoiseHistory = nan(o.MaxFrame,4);   %time, x, y, id
        
        %********** load in a fixation error sound ************
        [y,fs] = audioread(['SupportData',filesep,'gunshot_sound.wav']);
        y = y(1:floor(size(y,1)/3),:);  % shorten it, very long sound
        o.fixbreak_sound = y;
        o.fixbreak_sound_fs = fs;
        %*********************
    end
   
    function closeFunc(o)
        o.Bars.CloseUp();
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

          o.StartTex=randi(o.Bars.Ntex,1);
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

            %%  %updating bars
            kk = ~mod(o.PFrameCount, o.nFramesPerStim);
            
            if isempty(o.Bars.texnum)
                o.Bars.texnum  = randi(o.Bars.rng, o.Bars.Ntex);
                o.Bars.orinum  = randi(o.Bars.rng, length(o.P.orilist));
                o.Bars.prefori = o.P.prefori(o.Bars.orinum);
            elseif kk %update
                o.Bars.texnum  = randi(o.Bars.rng, o.Bars.Ntex);  %o.StartTex + kk;%o.Bars.texnum +1; %randi(o.Bars.rng, o.Bars.Ntex);  
                o.Bars.orinum  = randi(o.Bars.rng, length(o.P.orilist));
                o.Bars.prefori = o.P.orilist(o.Bars.orinum);
            end

            if o.Bars.texnum>o.Bars.Ntex
                o.Bars.texnum=rem(o.Bars.texnum-1,o.Bars.Ntex)+1;
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
                    o.Bars.position = [o.S.centerPix(1)+x, o.S.centerPix(2)+y];
                end
            end

            
            o.NoiseHistory(o.FrameCount,:) = [NaN,o.Bars.position,o.Bars.texnum];
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
                

                o.Bars.beforeFrame();
                o.hFix.beforeFrame(3); %Continue showing the black fixation dot?

                    if o.FrameCount>0
                    %Params for saving
                      o.ProbeHistory(o.FrameCount,1) = o.Bars.position(1);
                       o.ProbeHistory(o.FrameCount,2) = o.Bars.position(2);
                       o.ProbeHistory(o.FrameCount,3) = o.Bars.prefori;
                       o.ProbeHistory(o.FrameCount,5) = o.Bars.texnum;
                       
                       %Save the barcode (could get big, ideally wouldn't need to)
                       %Won't allow for size change during presentation, could
                       %change this to cell but there will be an overhead
                       o.BarHistory{o.FrameCount} =o.Bars.saveline(o.Bars.texnum,:);
                       %o.TexHistory(o.PFrameCount,:,:)=o.Bars.savesquare(:,:,o.Bars.texnum);
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
%                           o.BarHistory{o.FrameCount} = NaN;
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
                        
                        o.BarHistory{o.FrameCount} = NaN;
                    end
                end

      
        end

        %******** if sound, do here
        if (o.RunFixBreakSound == 1) && (o.NeverBreakSoundTwice == 0)  
           sound(o.fixbreak_sound,o.fixbreak_sound_fs);
           o.NeverBreakSoundTwice = 1;
        end
        %**************************************************************

        % TODO make this into it's own class and output 
        if isfield(o.S,'photodiode')
            dpout=find(cellfun(@(x) strcmp(x,'output_datapixx2'), o.S.outputs));
            if rem(o.FrameCount,o.S.frameRate/o.S.photodiode.TF)==1 % first frame flash photodiode
                Screen('FillRect',o.winPtr,o.S.photodiode.flash,o.S.photodiode.rect)
                
                %Should be <20 so shouldn't need to preallocate but..
                o.Flashtime=[o.Flashtime; currentTime];

                if dpout
                    %ttl4 high
                    outputs{dpout}.flipBitVideoSync(4,1)
                end
            else
                Screen('FillRect',o.winPtr,o.S.photodiode.init,o.S.photodiode.rect)
                if dpout
                    %ttl4 low
                    outputs{dpout}.flipBitVideoSync(4,0)
                end
            end
       % disp(rem(o.FrameCount,o.S.frameRate/o.S.photodiode.TF))
        end

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
            PR.BarHistory = [];
            %PR.TexHistory = [];
        else
            PR.NoiseHistory = o.NoiseHistory(1:o.FrameCount,:);
            PR.ProbeHistory = o.ProbeHistory(1:o.FrameCount,:);
            PR.BarHistory = o.BarHistory;%{1:o.FrameCount};
            %PR.TexHistory= o.TexHistory(1:o.FrameCount,:,:);
        end
    
        %%%% Record some data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        o.D.error(A.j) = o.error;
        o.D.x(A.j) = P.xDeg;
        o.D.y(A.j) = P.yDeg;
        o.D.fixDur(A.j) = o.fixDur;

        %Photodiode
        PR.Flashtime = o.Flashtime;

        
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
