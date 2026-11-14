classdef PR_Acuity_Continuous < handle
  % Matlab class for running an experimental protocl
  %
  % The class constructor can be called with a range of arguments:
  %
  
  properties (Access = public), 
       Iti double = 1;            % default Iti duration
       startTime double = 0;      % trial start time
       fixStart double = 0;       % fix acquired time
       itiStart double = 0;       % start of ITI interval
       lostStart double = 0;
       lastReward double = 0;
       RewardDur double =1;       % threshold for time followed to get a reward 
       fixDur double = 0;         % fixation duration
       stimStart double = 0;      % start of Gabor probe stimulus
       responseStart double = 0;  % start of choice period
       responseEnd double = 0;    % end of response period
       showFix logical = true;    % trial start with fixation
       flashCounter double = 0;   % counts frames, used for fade in point cue?
       rewardCount double = 0;    % counter for reward drops
       RunFixBreakSound double = 0;       % variable to initiate fix break sound (only once)
       NeverBreakSoundTwice double = 0;   % other variable for fix break sound
       MaxFrame double = 6000;
       ProbeHistory =[]
       Traces =[]
       targWinRadius double = 5;
       FrameCount double = 0;
       mode double =1;
  end
      
  properties (Access = private)
    winPtr; % ptb window
    state double = 0;      % state counter
    error double = 0;      % error state in trial
    %*********
    S;      % copy of Settings struct (loaded per trial start)
    P;      % copy of Params struct (loaded per trial)
    trialsList;  % list of trial types to run in experiment
    trialIndexer = [];  % object to run trial order
    %********* stimulus structs for use
    stimTheta double = 0;  % direction of choice
    hFix;              % object for a fixation point
    hProbe = [];       % object for Gabor stimuli
%     hChoice = [];      % object for Choice Gabor stimuli
    fixbreak_sound;    % audio of fix break sound
    fixbreak_sound_fs; % sampling rate of sound
    %****************
    D = struct;        % store PR data for end plot stats
  end
  
  methods (Access = public)
    function o = PR_Acuity_Continuous(winPtr)
      o.winPtr = winPtr; 
      o.trialsList = [];
    end
    
    function state = get_state(o)
        state = o.state;
    end
    
    function initFunc(o,S,P)
 
         %********** Set-up for trial indexing (required) 
         cors = [0,4];  % count these errors as correct trials
         reps = [1,2];  % count these errors like aborts, repeat
         o.trialIndexer = marmoview.TrialIndexer(o.trialsList,P,cors,reps);
         o.error = 0;  

        o.MaxFrame = ceil(20*S.frameRate);
        o.ProbeHistory = zeros(o.MaxFrame,5);  % time,x,y,sf,fixated
        o.Traces = zeros(o.MaxFrame,6);  % time,targx,targy,eyex,eyey, fixgood
        o.targWinRadius =5;
        

         %********** Initialize Graphics Objects
         o.hFix = stimuli.fixation(o.winPtr);   % fixation stimulus
        switch P.mode
            case 0
                o.hProbe = stimuli.grating(o.winPtr);  % grating probe
            case 1
                o.hProbe = stimuli.opticflow(o.winPtr); % optic flow
        end

         %********* if stimuli remain constant on all trials, set-them up here

         % set fixation point properties
         sz = P.fixPointRadius*S.pixPerDeg;
         o.hFix.cSize = sz;
         o.hFix.sSize = 2*sz;
         o.hFix.cColour = ones(1,3); % black
         o.hFix.sColour = repmat(255,1,3); % white
         o.hFix.position = [0,0]*S.pixPerDeg + S.centerPix;
         o.hFix.updateTextures();


         %********** load in a fixation error sound ************
         [y,fs] = audioread(['SupportData',filesep,'gunshot_sound.wav']);
         y = y(1:floor(size(y,1)/3),:);  % shorten it, very long sound
         o.fixbreak_sound = y;
         o.fixbreak_sound_fs = fs;
         %*********************
    end
   
    function closeFunc(o),
        o.hFix.CloseUp();
        o.hProbe.CloseUp();
        
    end
   
    function generate_trialsList(o,S,P)
           % nothing for this protocol
           
           % Spatial frequency sampling
           sf_sampling = logspace(log10(P.minFreq),log10(P.maxFreq),P.FreqNum);

            % Generate trials list
            o.trialsList = [];
            for zk = 1:size(sf_sampling,2)
                for k = 1:P.apertures   % do both choice directions
                   %**********
                    stimori = 90;  %always vertical
                    ango = (((k-1)/P.apertures)*2*pi) + (pi/4);
                    xpos = P.ecc * cos(ango);
                    ypos = P.ecc * sin(ango);
                    %*************
                    mjuice = 2 + floor(sf_sampling(zk)/2);  % give more juice for higher spatial freq
                    if (mjuice > P.rewardNumber)
                        mjuice = P.rewardNumber;
                    end
                    %*************
                    % storing list of trials, [Choice_xpos Choice_ypos  SpatFreq Phase Ori Juice_Amount] 
                    o.trialsList = [o.trialsList ; [xpos ypos sf_sampling(zk) 0  stimori mjuice]];
                    o.trialsList = [o.trialsList ; [xpos ypos sf_sampling(zk) 90 stimori mjuice]];
                end
            end           
    end
    
    function P = next_trial(o,S,P)
          %********************
          o.S = S;
          o.P = P;       
          %*******************

         %******* init Noise History with MaxDuration **************

          if P.runType == 1   % go through trials list
                i = o.trialIndexer.getNextTrial(o.error);
                %****** update trial parameters for next trial
                P.choiceX = o.trialsList(i,1);
                P.choiceY = o.trialsList(i,2);
                P.xDeg = 0;% P.choiceX;  % detection task, choice is at target
                P.yDeg = 0;%P.choiceY;
                P.cpd = o.trialsList(i,3);  
                P.phase = o.trialsList(i,4);
                P.orientation = o.trialsList(i,5);
                P.rewardNumber = o.trialsList(i,6);
          end

          % Generate a continuous series of x/y target positions from
          % Gaussian white-noise velocities for every run type.
          o.MaxFrame = ceil(max(20,P.stimDur + 1)*S.frameRate);
          vx = randn(1,o.MaxFrame-1).*P.speed./S.frameRate;
          vy = randn(1,o.MaxFrame-1).*P.speed./S.frameRate;
          P.targxvect = [0 cumsum(vx)];
          P.targyvect = [0 cumsum(vy)];

          % Clear traces from the preceding trial.
          o.ProbeHistory = zeros(o.MaxFrame,5);
          o.Traces = zeros(o.MaxFrame,6);
          o.targWinRadius = P.targWinRadius;
          o.P = P;
          
          % Calculate this for pie slice windowing for choice
          o.stimTheta = atan2(P.choiceY,P.choiceX);
          switch P.mode
              case 0
                  % Make Gabor stimulus texture
                  o.hProbe.pixperdeg =S.pixPerDeg;
                  o.hProbe.position = [(S.centerPix(1) + round(P.xDeg*S.pixPerDeg)),(S.centerPix(2) - round(P.yDeg*S.pixPerDeg))];
                  o.hProbe.radius = round(P.radius*S.pixPerDeg);
                  o.hProbe.orientation = P.orientation; % vertical for the right
                  o.hProbe.phase = P.phase;
                  o.hProbe.cpd = P.cpd;
                  o.hProbe.range = P.range;
                  o.hProbe.square = logical(P.squareWave);
                  o.hProbe.bkgd = P.bkgd;
                  o.hProbe.updateTextures();
                  %******************************************
              case 1
                  %Optic flow
                  o.hProbe(1).position = [(S.centerPix(1) + round(P.xDeg*S.pixPerDeg)),(S.centerPix(2) - round(P.yDeg*S.pixPerDeg))];
                    o.hProbe(1).f= 0.100; %0.01
                    o.hProbe(1).depth= 10; %2
                    % DrawDots size is diameter; map it to half a nominal cycle.
                    % Clamp to the point-size range reported by this GPU. The
                    % requested and rendered sizes are both saved with the trial.
                    requestedDotDiameterPix = (S.pixPerDeg/P.cpd)/2;
                    [minSmoothPointSize,maxSmoothPointSize] = ...
                        Screen('DrawDots',o.winPtr);
                    o.hProbe(1).size = min(max(requestedDotDiameterPix, ...
                        minSmoothPointSize),maxSmoothPointSize);
                    o.hProbe(1).vxyz= [0 0 -.1];
                    if isfield(P,'nDots')
                        o.hProbe(1).nDots = max(1,round(P.nDots));
                    else
                        o.hProbe(1).nDots = 2500;
                    end
                    o.hProbe(1).transparent= 0.5000;
                    o.hProbe(1).pixperdeg= S.pixPerDeg;
                    o.hProbe(1).screenRect= S.screenRect;
                    o.hProbe(1).colour= [1 1 1];
                    o.hProbe(1).bkgd = P.bkgd;
                    if isfield(P,'balancedDots')
                        o.hProbe(1).balancedDots = logical(P.balancedDots);
                    end
                    if isfield(P,'dotContrast')
                        effectiveContrast = P.dotContrast;
                        if isfield(P,'normalizeDotRms') && logical(P.normalizeDotRms)
                            rmsExponent = 1;
                            if isfield(P,'dotRmsExponent')
                                rmsExponent = P.dotRmsExponent;
                            end
                            referenceCpd = max(P.minFreq,P.maxFreq);
                            effectiveContrast = effectiveContrast* ...
                                (P.cpd/referenceCpd).^rmsExponent;
                        end
                        o.hProbe(1).dotContrast = min(max(effectiveContrast,0),1);
                    end
                    if isfield(S,'coneColor')
                        if isfield(S.coneColor,'RequiresUnitDotContrast') && ...
                                logical(S.coneColor.RequiresUnitDotContrast) && ...
                                abs(o.hProbe(1).dotContrast-1) > 1e-12
                            error('PR_Acuity_Continuous:CalibratedContrast', ...
                                ['This calibrated stimulus requires dotContrast=1. ' ...
                                'Regenerate calibrated endpoints to change contrast.']);
                        end
                        o.hProbe(1).polarityColours = [ ...
                            S.coneColor.NegativeRGB255(:), ...
                            S.coneColor.PositiveRGB255(:)];
                        o.hProbe(1).neutralColour = ...
                            S.coneColor.BackgroundRGB255(:);
                    end
                    if isfield(P,'dotMinSeparation')
                        o.hProbe(1).minSeparationPix = ...
                            max(0,P.dotMinSeparation)*S.pixPerDeg;
                    end
                    if isfield(P,'dotPlacementAttempts')
                        o.hProbe(1).placementAttempts = ...
                            max(1,round(P.dotPlacementAttempts));
                    end
                    o.hProbe(1).maxRadius= inf;
                    o.hProbe(1).lifetime= 30;
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
                    o.hProbe(1).beforeTrial();
          end
    end
    
    function [FP,TS] = prep_run_trial(o)
        
          %********VARIABLES USED IN RUNNING TRIAL LOGISTICS
          o.fixDur = o.P.fixMin + ceil(1000*o.P.fixRan*rand)/1000;  % randomized fix duration
          % showFix is a flag to check whether to show the fixation spot or not while
          % it is flashing in state 0
          o.showFix = true;
          % flashCounter counts the frames to switch ShowFix off and on
          o.flashCounter = 0;
          % rewardCount counts the number of juice pulses, 1 delivered per frame
          o.rewardCount = 0;
          o.FrameCount = 0;
          %****** deliver sound on fix breaks
          o.RunFixBreakSound =0;
          o.NeverBreakSoundTwice = 0;  
          % Setup the state
          o.state = 0; % Showing the face
          o.error = 0; % Start with error as 0
          o.Iti = o.P.iti;   % set ITI interval from P struct stored in trial
          %******* Plot States Struct (show fix in blue for eye trace)
          % any special plotting of states, 
          % FP(1).states = 1:2; FP(1).col = 'b';
          % would show states 1,2 in blue for eye trace
          FP(1).states = 1:3;  %before fixation
          FP(1).col = 'b';
          FP(2).states = 4;  % fixation held
          FP(2).col = 'g';
          FP(3).states = 5;
          FP(3).col = 'r';
          %******* set which states are TimeSensitive, if [] then none
          TS = 1:5;  % all times during target presentation
          %********
          o.startTime = GetSecs;
    end
    
    function keepgoing = continue_run_trial(o,screenTime)
        if o.FrameCount > 0
            o.ProbeHistory(o.FrameCount,1) = screenTime;
        end
        keepgoing = 0;
        if (o.state < 9)
            keepgoing = 1;
        end
    end
   
    %******************** THIS IS THE BIG FUNCTION *************
    function drop = state_and_screen_update(o,currentTime,x,y,varargin)  
        drop = 0;
        %******* THIS PART CHANGES WITH EACH PROTOCOL ****************
        
        % POLAR COORDINATES FOR PIE SLICE METHOD, note three values of polT to
        % ensure atan2 discontinuity does not wreck shit
        polT = atan2(y,x)+[-2*pi 0 2*pi];
        polR = norm([x y]);

        %%%%% STATE 0 -- GET INTO FIXATION WINDOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % If eye travels within the fixation window, move to state 1
        if o.state == 0 && norm([x y]) < o.P.initWinRadius
            o.state = 1; % Move to fixation grace
            o.fixStart = GetSecs;
        end

        % Trial expires if not started within the start duration
        if o.state == 0 && currentTime > o.startTime + o.P.startDur
            o.state = 8; % Move to iti -- inter-trial interval
            o.error = 1; % Error 1 is failure to initiate
            o.itiStart = GetSecs;
        end

        %%%%% STATE 1 -- GRACE PERIOD TO BE IN FIXATION WINDOW %%%%%%%%%%%%%%%%
        % A grace period is given before the eye must remain in fixation
        if o.state == 1 && currentTime > o.fixStart + o.P.fixGrace
            if norm([x y]) < o.P.initWinRadius
                o.state = 2; % Move to hold fixation
            else
                o.state = 8;
                o.error = 1; % Error 1 is failure to initiate
                o.itiStart = GetSecs;
            end
        end

        %%%%% STATE 2 -- HOLD FIXATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % If fixation is held for the fixation duration, move to state 3
        if o.state == 2 && currentTime > o.fixStart + o.fixDur
            o.state = 3; % Move to show stimulus
            %***** reward here for holding of fixation
            if (isfield(o.P,'rewardFix'))
                if (o.P.rewardFix)
                  drop = 1;
                end
            end
            %************************
            o.stimStart = GetSecs;
            o.lastReward = GetSecs;
        end

        % Eye must remain in the fixation window
        if o.state == 2 && norm([x y]) > o.P.fixWinRadius
            o.state = 8; % Move to iti -- inter-trial interval
            o.error = 2; % Error 2 is failure to hold fixation
            o.itiStart = GetSecs;
        end

        %%%% STATE 3, SHOWING STIMULUS. Reward if stays close for a while,
                %%%% end if moves too far from the target
        targx=(o.hProbe.position(1)-o.S.centerPix(1))/o.S.pixPerDeg;
        targy=-(o.hProbe.position(2)-o.S.centerPix(2))/o.S.pixPerDeg;
        distSquared = (x-targx).^2 + (y-targy).^2;

        if ((o.state == 3) || (o.state == 4)) && distSquared <= o.P.targWinRadius.^2
            o.state = 3; % stay in/reenter state
            %Reward if followed stim for 1 second
            if ~o.error && o.rewardCount < o.P.rewardNumber && (currentTime-o.lastReward)>o.P.RewardDur
                   o.rewardCount = o.rewardCount + 1;
                   drop = 1;
                   o.lastReward=GetSecs;
            end

        elseif o.state == 3 && distSquared > o.P.targWinRadius.^2
            o.state = 4; %enter grace period for lost target
            o.lostStart = currentTime;
        end

        % Target is lost, and has continued to be lost (otherwise it would
        % have moved to state 3)
        if o.state == 4 && currentTime > o.lostStart + o.P.lostgrace
            o.state = 7; % Move to iti -- inter-trial interval
            o.error = 3; % Error 3 is lost target
            o.itiStart = GetSecs;
        end

        %Timeout
        if ((o.state == 3) || (o.state == 4)) && currentTime > o.stimStart + o.P.stimDur
            o.state = 7; % Move to iti -- inter-trial interval
            o.error = 0; % No error here
            o.itiStart = GetSecs;
        end


        %%%%% STATE 7 -- INTER-TRIAL INTERVAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Deliver rewards
        if o.state == 7 
            if ~o.error && o.rewardCount < o.P.rewardNumber
               if currentTime > o.itiStart + 0.2*o.rewardCount % deliver in 200 ms increments
                   o.rewardCount = o.rewardCount + 1;
                   drop = 1;
               end
            else
               o.state = 8;
            end
        end

        %******* fixation break feedback, but otherwise go to state 9
        if o.state == 8
               if currentTime > o.itiStart + 0.2   % enough time to flash fix break 
                  o.state = 9; 
                  if o.error 
                     o.Iti = o.P.iti + o.P.blank_iti;
                  end
               end
        end

        % STATE SPECIFIC DRAWS


        switch o.state
            case 0
                %******* flash fixation point to draw monkey to it
                if o.showFix
                    o.hFix.beforeFrame(1);
                end
                o.flashCounter = mod(o.flashCounter+1,o.P.flashFrameLength);
                if o.flashCounter == 0
                    o.showFix = ~o.showFix;
                end

            case 1
                % Bright fixation spot, prior to stimulus onset                    
                o.hFix.beforeFrame(1);

            case 2
                % Continue to show fixation for a hold period       
                o.hFix.beforeFrame(1);

            case {3,4}                
                %********* show stimulus if still appropriate
                if ( currentTime < o.stimStart + o.P.stimDur )
                    %Update to the next position of the probe
                    o.updatetarget(x,y,currentTime)
                end
                
                
            case 8
                if (o.error == 2) % broke fixation
                    o.hFix.beforeFrame(2);    
                    %once you have a sound object, put break fix here
                    o.RunFixBreakSound = 1;
                end
                % leave everything blank for a minimum ITI           
        end
        
        %******** if sound, do here
        if (o.RunFixBreakSound == 1) & (o.NeverBreakSoundTwice == 0)  
           sound(o.fixbreak_sound,o.fixbreak_sound_fs);
           o.NeverBreakSoundTwice = 1;
        end
        %**************************************************************
    end
    
    function updatetarget(o,xx,yy,currentTime)
        o.FrameCount = o.FrameCount + 1;     

        %Store current position of targets and eyes, from previous frame
        %this should end up being the same as data stored in o.ProbeHistory
        o.Traces(o.FrameCount,1)=currentTime;
        targx=(o.hProbe.position(1)-o.S.centerPix(1))/o.S.pixPerDeg;
        targy=-(o.hProbe.position(2)-o.S.centerPix(2))/o.S.pixPerDeg;
        o.Traces(o.FrameCount,2)=targx;
        o.Traces(o.FrameCount,3)=targy;
        o.Traces(o.FrameCount,4)=xx;
        o.Traces(o.FrameCount,5)=yy;

        
        if o.state==3
            o.Traces(o.FrameCount,6) = 1;
        elseif o.state==4
            o.Traces(o.FrameCount,6) = 1; %0;%NO! Need to preserve time course/lags
        end

        %Update position for next frame
        o.hProbe.afterFrame();
        o.hProbe.position = [(o.S.centerPix(1) + round(o.P.targxvect(o.FrameCount)*o.S.pixPerDeg)),(o.S.centerPix(2) - round(o.P.targyvect(o.FrameCount)*o.S.pixPerDeg))];
        o.hProbe.beforeFrame();

         % NOTE: store screen time in "continue_run_trial" after flip, time
         % when stimuli actually appears
        o.ProbeHistory(o.FrameCount,2) = o.hProbe.position(1);  
        o.ProbeHistory(o.FrameCount,3) = o.hProbe.position(2); 

        switch o.P.mode
            case 0
                o.ProbeHistory(o.FrameCount,4) = o.hProbe.cpd; %SF
            case 1
                o.ProbeHistory(o.FrameCount,4) = o.hProbe.size; %size of dot
        end
        
        if o.state==3
            o.ProbeHistory(o.FrameCount,5) = 1;
        elseif o.state==4
            o.ProbeHistory(o.FrameCount,5) = 0;
        end
    end


    function Iti = end_run_trial(o)
        Iti = o.Iti - (GetSecs - o.itiStart); % returns generic Iti interval
    end
    
    function plot_trace(o,handles)
        % This function plots the eye trace from a trial in the EyeTracker
        % window of MarmoView.

        h = handles.EyeTrace;
        % Fixation window
        set(h,'NextPlot','Replace');
        r = o.P.fixWinRadius;
        plot(h,r*cos(0:.01:1*2*pi),r*sin(0:.01:1*2*pi),'--k');
        set(h,'NextPlot','Add');
        
        trialTraces = o.Traces(1:o.FrameCount,:);
        targX = trialTraces(:,2);
        targY = trialTraces(:,3);
        eyeX = trialTraces(:,4);
        eyeY = trialTraces(:,5);

        plot(h,targX,targY,'k.')
        plot(h,eyeX(trialTraces(:,6)==1),eyeY(trialTraces(:,6)==1),'b.')
        plot(h,eyeX(trialTraces(:,6)~=1),eyeY(trialTraces(:,6)~=1),'r.')



        
        eyeRad = handles.eyeTraceRadius;
        axis(h,[-eyeRad eyeRad -eyeRad eyeRad]);

%         % Stimulus window
%         stimX = o.P.choiceX; 
%         stimY = o.P.choiceY; 
%         eyeRad = handles.eyeTraceRadius;
%         minR = o.P.stimWinMinRad;
%         maxR = o.P.stimWinMaxRad;
%         errT = o.P.stimWinTheta;
%         stimT = atan2(stimY,stimX);
% 
%         plot(h,[minR*cos(stimT+errT) maxR*cos(stimT+errT)],[minR*sin(stimT+errT) maxR*sin(stimT+errT)],'--k');
%         plot(h,[minR*cos(stimT-errT) maxR*cos(stimT-errT)],[minR*sin(stimT-errT) maxR*sin(stimT-errT)],'--k');
%         plot(h,minR*cos(stimT-errT:pi/100:stimT+errT),minR*sin(stimT-errT:pi/100:stimT+errT),'--k');
%         plot(h,maxR*cos(stimT-errT:pi/100:stimT+errT),maxR*sin(stimT-errT:pi/100:stimT+errT),'--k');
%         r = o.P.radius;
%         plot(h,stimX+r*cos(0:.01:1*2*pi),stimY+r*sin(0:.01:1*2*pi),'-k');
%         axis(h,[-eyeRad eyeRad -eyeRad eyeRad]);
    end
    
    function PR = end_plots(o,P,A)   %update D struct if passing back info
        
        %************* STORE DATA to PR
        PR = struct;
        PR.error = o.error;
        PR.fixDur = o.fixDur;
        PR.x = P.xDeg;
        PR.y = P.yDeg;
        PR.choiceX = P.choiceX;
        PR.choiceY = P.choiceY;
        % Retain cpd for backward compatibility, but treat dot diameter as
        % the physical independent variable for optic-flow trials.
        PR.cpd = P.cpd;
        PR.nominalCpd = P.cpd;
        if P.mode == 1
            PR.requestedDotDiameterPix = (o.S.pixPerDeg/P.cpd)/2;
            PR.dotDiameterPix = o.hProbe.size;
            PR.dotDiameterDeg = o.hProbe.size/o.S.pixPerDeg;
            PR.dotDiameterWasClamped = abs(PR.dotDiameterPix - ...
                PR.requestedDotDiameterPix) > 10*eps(PR.dotDiameterPix);
            PR.effectiveDotCpd = o.S.pixPerDeg/(2*PR.dotDiameterPix);
            PR.conditionValue = PR.dotDiameterDeg;
            PR.conditionUnits = 'deg dot diameter';
            PR.nDots = o.hProbe.nDots;
            PR.balancedDots = o.hProbe.balancedDots;
            PR.dotContrast = o.hProbe.dotContrast;
            if isfield(P,'dotContrast')
                PR.dotContrastAtSmallestSize = P.dotContrast;
            end
            if isfield(P,'normalizeDotRms')
                PR.normalizeDotRms = logical(P.normalizeDotRms);
            end
            if isfield(P,'dotRmsExponent')
                PR.dotRmsExponent = P.dotRmsExponent;
            end
            PR.dotMinSeparationDeg = o.hProbe.minSeparationPix/o.S.pixPerDeg;
            PR.dotPlacementFallbacks = o.hProbe.placementFallbackCount;
            PR.dotPlacementCalls = o.hProbe.placementCalls;
            PR.dotPlacementCandidates = o.hProbe.placementCandidateCount;
            PR.dotPlacementDistanceChecks = o.hProbe.placementDistanceChecks;
            PR.dotPlacementTimeMs = 1000*o.hProbe.placementTimeSeconds;
            PR.dotCachedReplacementCount = o.hProbe.cachedReplacementCount;
            PR.dotReplacementMode = 'cached pre-trial layout';
            PR.stimulusFamily = 'broadband polarity-balanced dots';
            if isfield(o.S,'coneColor')
                PR.stimulusFamily = 'human cone-opponent balanced dots';
                PR.coneAxisLabel = o.S.coneAxisLabel;
                PR.conePeaksNm = o.S.coneColor.ConePeaks;
                PR.coneAxis = o.S.coneColor.ConeAxis;
                PR.coneAxisAmplitude = o.S.coneColor.AxisAmplitude;
                PR.maximumSymmetricConeAxisAmplitude = ...
                    o.S.coneColor.MaximumSymmetricAxisAmplitude;
                PR.neutralLinearRGB = o.S.coneColor.BackgroundLinearRGB;
                PR.negativeLinearRGB = o.S.coneColor.NegativeLinearRGB;
                PR.positiveLinearRGB = o.S.coneColor.PositiveLinearRGB;
                PR.negativeConeContrast = o.S.coneColor.NegativeConeContrast;
                PR.positiveConeContrast = o.S.coneColor.PositiveConeContrast;
                PR.presentedNegativeLinearRGB = ...
                    o.S.coneColor.BackgroundLinearRGB + o.hProbe.dotContrast* ...
                    (o.S.coneColor.NegativeLinearRGB- ...
                    o.S.coneColor.BackgroundLinearRGB);
                PR.presentedPositiveLinearRGB = ...
                    o.S.coneColor.BackgroundLinearRGB + o.hProbe.dotContrast* ...
                    (o.S.coneColor.PositiveLinearRGB- ...
                    o.S.coneColor.BackgroundLinearRGB);
                PR.presentedNegativeConeContrast = ...
                    o.hProbe.dotContrast*o.S.coneColor.NegativeConeContrast;
                PR.presentedPositiveConeContrast = ...
                    o.hProbe.dotContrast*o.S.coneColor.PositiveConeContrast;
                PR.coneCalibrationSource = o.S.coneColor.Source;
                if isfield(o.S.coneColor,'NegativeDeviceCodes')
                    PR.negativeDeviceCodes = o.S.coneColor.NegativeDeviceCodes;
                    PR.positiveDeviceCodes = o.S.coneColor.PositiveDeviceCodes;
                    PR.realizedNegativeConeContrast = ...
                        o.S.coneColor.RealizedNegativeConeContrast;
                    PR.realizedPositiveConeContrast = ...
                        o.S.coneColor.RealizedPositiveConeContrast;
                end
                if isfield(o.S.coneColor,'PhotopicLuminanceRGB')
                    PR.photopicLuminanceRGB = ...
                        o.S.coneColor.PhotopicLuminanceRGB;
                    PR.photopicLuminanceConvention = ...
                        o.S.coneColor.PhotopicLuminanceConvention;
                    if isfield(o.S.coneColor,'PhotopicLuminanceSource')
                        PR.photopicLuminanceSource = ...
                            o.S.coneColor.PhotopicLuminanceSource;
                    end
                    PR.negativeCIEYContrast = ...
                        o.S.coneColor.NegativeCIEYContrast;
                    PR.positiveCIEYContrast = ...
                        o.S.coneColor.PositiveCIEYContrast;
                    PR.realizedNegativeCIEYContrast = ...
                        o.S.coneColor.RealizedNegativeCIEYContrast;
                    PR.realizedPositiveCIEYContrast = ...
                        o.S.coneColor.RealizedPositiveCIEYContrast;
                    PR.realizedNegativeCIEYResidual = ...
                        o.S.coneColor.RealizedNegativeCIEYResidual;
                    PR.realizedPositiveCIEYResidual = ...
                        o.S.coneColor.RealizedPositiveCIEYResidual;
                    PR.behavioralCIEYPerMContrast = ...
                        o.S.coneColor.BehavioralCIEYPerMContrast;
                    PR.realizedMaximumSilentLeakage = ...
                        o.S.coneColor.RealizedMaximumSilentLeakage;
                end
                if isfield(o.S.coneColor,'Warning')
                    PR.coneCalibrationWarning = o.S.coneColor.Warning;
                end
                if isfield(o.S.coneColor,'PhenotypeID')
                    PR.conePhenotypeID = o.S.coneColor.PhenotypeID;
                end
                if isfield(o.S.coneColor,'MonitorTarget')
                    PR.coneMonitorTarget = o.S.coneColor.MonitorTarget;
                end
            end

            frameIntervals = diff(o.ProbeHistory(1:o.FrameCount,1));
            frameIntervals = frameIntervals(isfinite(frameIntervals) & frameIntervals > 0);
            expectedInterval = 1/o.S.frameRate;
            PR.frameTimingThresholdMs = 1000*1.5*expectedInterval;
            PR.longFrameCount = nnz(frameIntervals > 1.5*expectedInterval);
            PR.longFrameFraction = PR.longFrameCount/max(1,numel(frameIntervals));
            if isempty(frameIntervals)
                PR.meanFrameIntervalMs = NaN;
                PR.maxFrameIntervalMs = NaN;
            else
                PR.meanFrameIntervalMs = 1000*mean(frameIntervals);
                PR.maxFrameIntervalMs = 1000*max(frameIntervals);
            end
        end
        %******* this is also where you could store Gabor Flash Info

        if o.FrameCount == 0
            PR.Traces = [];
            PR.ProbeHistory = [];
        else
            PR.Traces            = o.Traces(1:o.FrameCount,:);
            PR.ProbeHistory     = o.ProbeHistory(1:o.FrameCount,:);
        end
        
        
        %%%% Record some data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Remove the first 0.25 s because fixation supplies the starting
        % position. Keep failed/short trials, but do not analyze them.
        analysisTraces = o.Traces(1:o.FrameCount,:);
        discardFrames = min(round(0.25*o.S.frameRate),o.FrameCount);
        analysisTraces(1:discardFrames,6) = 0;
        valid = analysisTraces(:,6) == 1 & ...
            all(isfinite(analysisTraces(:,2:5)),2);
        targX = analysisTraces(valid,2);
        targY = analysisTraces(valid,3);
        eyeX = analysisTraces(valid,4);
        eyeY = analysisTraces(valid,5);
        nvalid = nnz(valid);
        maxLag = round(o.S.frameRate);
        CCG = nan(1,2*maxLag + 1);
        proj = NaN;

        if nvalid >= 3
            smoothFrames = max(1,min(nvalid,round(0.1*o.S.frameRate)));
            eyevX = diff(smooth(eyeX,smoothFrames));
            eyevY = diff(smooth(eyeY,smoothFrames));
            eyetargX = targX-eyeX;
            eyetargY = targY-eyeY;

            projection = (eyevX.*eyetargX(2:end) + eyevY.*eyetargY(2:end)) ./ ...
                (hypot(eyevX,eyevY).*hypot(eyetargX(2:end),eyetargY(2:end)));
            proj = mean(projection,'omitnan');
            CCG = xcorr(eyevX + 1i*eyevY, ...
                eyetargX(2:end) + 1i*eyetargY(2:end),maxLag).';
        end

        o.D.ccg(A.j,:)=CCG;
        o.D.proj(A.j,:)=proj;
        o.D.nvalid(A.j)=nvalid;
        o.D.error(A.j) = o.error;
        o.D.xDeg(A.j) = P.xDeg;
        o.D.yDeg(A.j) = P.yDeg;
        o.D.x(A.j) = P.choiceX; 
        o.D.y(A.j) = P.choiceY; 
        o.D.cpd(A.j) = P.cpd;
        if P.mode == 1
            o.D.dotDiameterDeg(A.j) = o.hProbe.size/o.S.pixPerDeg;
            o.D.dotContrast(A.j) = o.hProbe.dotContrast;
            o.D.dotPlacementFallbacks(A.j) = o.hProbe.placementFallbackCount;
            o.D.dotPlacementTimeMs(A.j) = 1000*o.hProbe.placementTimeSeconds;
            o.D.dotPlacementDistanceChecks(A.j) = o.hProbe.placementDistanceChecks;
            o.D.dotCachedReplacementCount(A.j) = o.hProbe.cachedReplacementCount;
        end
        

        %%%% Plot results %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


        %Also want to plot mean distance to help correct calibration
        offX=targX-eyeX;
        offY=targY-eyeY;
        plot(A.DataPlot1,0,0,'kx');
        plot(A.DataPlot1,offX,offY,'b.');
        
        set(A.DataPlot1,'DataAspectRatio',[1 1 1],'XLim',[-o.targWinRadius o.targWinRadius],'YLim',[-o.targWinRadius o.targWinRadius]);
        title(A.DataPlot1,'Eye-target (calib) error ');
% 


        % Dataplot3, mean pursuit projection by inverse-size condition.
        cpds = unique(o.trialsList(:,3));
        ncpds = size(cpds,1);
        fcXcpd = zeros(1,ncpds);
        proj_all = zeros(1,ncpds);
        labels = cell(1,ncpds);
        maxLag = round(o.S.frameRate);
        CCG_all = nan(2*maxLag+1,ncpds);
        for i = 1:ncpds
            cpd = cpds(i);

            % Combine CCGs, weight by nvalues so to not get thrown off by
            % outliers
            trialMask = o.D.cpd == cpd & o.D.nvalid >= 3 & isfinite(o.D.proj);
            if any(trialMask)
                weights = o.D.nvalid(trialMask);
                CCG_all(:,i) = (weights*o.D.ccg(trialMask,:)./sum(weights)).';
                proj_all(i) = mean(o.D.proj(trialMask),'omitnan');
            else
                proj_all(i) = NaN;
            end

            fcXcpd(i) = proj_all(i);
            labels{i} = sprintf('%.4f',1/(2*cpd));
        end
        
        %Plot most recent cpd presented
        i=find(cpds==P.cpd);
        lagSeconds = (-maxLag:maxLag)./o.S.frameRate;
        plot(A.DataPlot2,lagSeconds,abs(CCG_all(:,i)),'b',lagSeconds,ones(length(CCG_all(:,i)),1)*median(abs(CCG_all(:,i)),'omitnan'),'r-')
        title(A.DataPlot2,sprintf('CCG, dot %.4f deg',1/(2*P.cpd)));
        
        %legend(A.DataPlot2,num2str(cpds))


        bar(A.DataPlot3,1:ncpds,fcXcpd);
        title(A.DataPlot3,'By dot diameter');
        ylabel(A.DataPlot3,'Mean pursuit projection');
        xlabel(A.DataPlot3,'Dot diameter (deg)');
        set(A.DataPlot3,'XTickLabel',labels);
%         if any(fcXcpd>1)
%             huh=1; % How can xcorr give values>1 here
%         end
        axis(A.DataPlot3,[.25 ncpds+.75 -1 1]);
    end
    
  end % methods
    
end % classdef
