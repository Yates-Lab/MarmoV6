classdef PR_IBLContrastGabor < handle
  % IBL protocol
  %
  % The class constructor can be called with a range of arguments:
  %Screen('Preference', 'SkipSyncTests', 1);
  properties (Access = public) 
       Iti double = 1;            % default Iti duration
       startTime double = 0;      % trial start time
       fixStart double = 0;       % fix acquired time
       itiStart double = 0;       % start of ITI interval
       fixDur double = 0;         % fixation duration
       stimStart double = 0;      % start of Gabor probe stimulus
       responseStart double = 0;  % start of choice period
       responseEnd double = 0;    % end of response period
       showFix logical = true;    % trial start with fixation
       flashCounter double = 0;   % counts frames, used for fade in point cue?
       rewardCount double = 0;    % counter for reward drops
       checkpointTimes double = [0 0 0 0];
       checkpoints double = [0 0 0 0];
       checkpointFlags double = [0 0 0 0];
       check = 1;
       rewardTimes double = [0 0 0 0];
       
       RunFixBreakSound double = 0;       % variable to initiate fix break sound (only once)
       NeverBreakSoundTwice double = 0;   % other variable for fix break sound
       RunMoErrorSound double = 0;
       NeverMoErrorSoundTwice double = 0;
       RunRewardSound double = 0;
       NeverRewardSoundtwice double = 0;

       Faces             % object that stores face images for use
       faceTime = 0.1    % time for showing face stimulus
  end

      
  properties (Access = private)
    winPtr; %ptb window
    state double = 0;      % state counter
    error double = 0;      % error state in trial
    contrast double = 0;
    stimPos double = 0;
    S;      % copy of Settings struct (loaded per trial start)
    P;      % copy of Params struct (loaded per trial)
    trialsList        % list of trials types to run in experiment 
    trialIndexer = [];
    %********* stimulus structs for use
    hFix;             % objetc for a fixation point 
    hProbe = []       % object for Gabor stimuli
    fixbreak_sound;   % audio of fix break cound 
    fixbreak_sound_fs;% sampling rate of sound 
    motionerror_sound;
    motionerror_sound_fs;
    reward_sound;
    reward_sound_fs;

    
    %********* structure for end plot stats 
    D struct = struct()        % store PR data for end plot stats, will store dotmotion array
  end
  
  methods (Access = public)
      function o = PR_IBLContrastGabor(winPtr)
          o.winPtr = winPtr;
          o.trialsList = [];
      end

      function state = get_state(o)
          state = o.state;
      end

    
    function initFunc(o,S,P)
  
       %********** Set-up for trial indexing (required) 
       cors = [0,3,4];  % count these errors as correct trials
       reps = [1,2];  % count these errors like aborts, repeat
       o.trialIndexer = marmoview.TrialIndexer(o.trialsList,P,cors,reps);
       o.error = 0;  
       %********** init reward face for correct trials
       o.faceTime = P.faceTime;
       o.Faces = stimuli.gaussimages(o.winPtr,'bkgd',S.bgColour,'gray',false);   % color images
       o.Faces.loadimages('./SupportData/MarmosetFaceLibrary.mat');
       o.Faces.position = [0,0]*S.pixPerDeg + S.centerPix;
       o.Faces.radius = round(P.faceradius*S.pixPerDeg);
       o.Faces.imagenum = 1;  % start first face
       o.Faces.transparency = -1;  % blend into background

       %********** Initialize Graphics Objects
         o.hFix = stimuli.fixation(o.winPtr);   % fixation stimulus
         o.hProbe = stimuli.grating_procedural(o.winPtr);  % grating probe
         
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

         [y,fs] = audioread(['SupportData',filesep,'incorrect.wav']);
         y = y(1:floor(size(y,1)/3),:);  % shorten it, very long sound
         o.motionerror_sound = y;
         o.motionerror_sound_fs = fs;

         [y,fs] = audioread(['SupportData',filesep,'reward.wav']);
         o.reward_sound = y;
         o.reward_sound_fs = fs;

       
       
    end
   
   
    function closeFunc(o)
        o.hFix.CloseUp();
        o.hProbe.CloseUp();
        
    end
   

    function generate_trialsList(o,S,P)  % the randmized trial list 
        % contrast/transparency smapling 
        cs = [P.minContrast,logspace(log10(P.contrast),log10(P.maxContrast),P.ContrastNum-1)];
        % Gabor Probe initial x-positions 
        xs = [-P.ecc, P.ecc];
        ys = [0];
        % generate trial list 
        [xx,yy,cc] = ndgrid(xs, ys, cs);
        c = cell(size(xx));
        for i = 1:numel(xx)
            % Set up conditions
            c{i}.stimPos    = [ xx(i), yy(i)]; % stim position relative to center
            c{i}.contrast   = cc(i);
            
        end
        sz  = prod(size(c));        
        c = cell2mat(reshape(c,sz,1));
        cmat = repmat(c,P.repeats,1);
        o.trialsList = cmat;  
 
    end
        
    
    function P = next_trial(o,S,P)
          %********************
          o.S = S;
          o.P = P;
    
          if P.runType == 1   % go through trials list    
                idx = o.trialIndexer.getNextTrial(o.error);
                %****** update trial parameters for next trial
                P.stimPos = o.trialsList(idx).stimPos;
                P.contrast = o.trialsList(idx).contrast;
                
                %******************
                o.P = P;  % set to most current
          end

          %***** Make Gabor stimulus texture
            % update o.P based on trialsList 
          o.P.StimX = [(S.centerPix(1) + round(P.stimPos(1)*S.pixPerDeg))];%,S.centerPix(2)];
          o.P.bound = 2*round(P.stimPos(1)*S.pixPerDeg); 
          o.P.MotionAccepBound = round(1*S.pixPerDeg); 
          o.P.checkpoints = [0.75, 0.5, 0.25 , 0];
          o.checkpoints = round(P.stimPos(1)*S.pixPerDeg).*o.P.checkpoints; % checkpoint positions in pix
          o.check = 1; % checkpoint indicator 
          

          o.hProbe.position = [o.P.StimX,S.centerPix(2)];
          o.hProbe.transparent = P.contrast;
          o.hProbe.gauss = true;
          o.hProbe.radius = round(P.radius*S.pixPerDeg);
          o.hProbe.orientation = P.orientation; % vertical for the right
          o.hProbe.phase = P.phase;
          o.hProbe.cpd = P.cpd;
          o.hProbe.range = 127; %P.range;
          o.hProbe.square = false;%logical(P.squareWave);
          o.hProbe.bkgd = S.bgColour;P.bkgd;
          o.hProbe.updateTextures();
          o.hProbe.pixPerDeg = S.pixPerDeg;

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
          %****** deliver sound on fix breaks
          o.RunFixBreakSound =0;
          o.NeverBreakSoundTwice = 0;  
          o.RunMoErrorSound =0;
          o.NeverMoErrorSoundTwice=0;
          o.RunRewardSound =0;
          o.NeverRewardSoundtwice=0
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
        keepgoing = 0;
        if (o.state < 9)
            keepgoing = 1;
        end
        
    end
   
    
    
    %******************** THIS IS THE BIG FUNCTION *************
    function drop = state_and_screen_update(o,currentTime,x,y,inputs);
        drop = 0;

     
        [wheelPos, ~] = getinput(inputs{end});


        %inputs is a cell array of handles for inputs
        %Read out the updated inputs here, but don't update the values. 
        % Everything here should be predetermined 

        %******* THIS PART CHANGES WITH EACH PROTOCOL ****************
        

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
            %AND RECORD INITIAL MOUSE POSITION:
           xm = wheelPos;
           o.P.xm0=xm;

            %***** reward here for holding of fixation
            if (isfield(o.P,'rewardFix'))
                if (o.P.rewardFix)
                  drop = 1;
                end
            end
            %************************
            o.stimStart = GetSecs;
            o.responseStart = GetSecs;
        end
        % Eye must remain in the fixation window
        if o.state == 2 && norm([x y]) > o.P.fixWinRadius
            o.state = 8; % Move to iti -- inter-trial interval
            o.error = 2; % Error 2 is failure to hold fixation
            o.itiStart = GetSecs;
        end


        %%%%% STATE 3 -- SHOW STIMULUS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Eye leaving fixation indicates a saccade, move to state 4
        if o.state == 3 && currentTime <= o.stimStart + o.P.noresponseDur

            if abs(o.hProbe.position(1)  - o.S.centerPix(1)) < abs(o.P.bound) %&& o.hProbe.position(1) > o.P.bound(2)
                % if the stimPos is still within the bounds, not reaching the cneter
                xm = wheelPos;
                
                x0 = o.hProbe.position(1); %initial/current probe position
                xm0 = o.P.xm0; % previous wheel position
                dx = xm-xm0; % change in position of wheel in pixel space
                %disp(xm)
                o.hProbe.position(1) = x0 + dx; %new position of probe in pixel space       
                o.P.xm0 = xm; % Update xm0 and pass to o.P for next frame
                
                % *** check the checkpoints 
                if abs(o.hProbe.position(1) - o.S.centerPix(1)) < abs(o.checkpoints(1))
                    o.checkpointTimes(1) = GetSecs;
                    o.checkpointFlags(1) = 1;
                   
                    if o.rewardCount < o.P.rewardNumber(1) && o.check == 1
                            o.rewardCount = o.rewardCount + 1;
                            drop = 1;
                            o.rewardTimes(1) = GetSecs;
                            o.check = 2;
                    else
                        o.rewardCount = 0;                   
                        drop = 0;
                    end

                end

                if abs(o.hProbe.position(1) - o.S.centerPix(1)) < abs(o.checkpoints(2)) 
                    o.checkpointTimes(2) = GetSecs;
                    o.checkpointFlags(2) = 1;
                    
                     if o.rewardCount < o.P.rewardNumber(1) && o.check==2
                            o.rewardCount = o.rewardCount + 1;
                            drop = 1;
                            o.rewardTimes(2) = GetSecs;
                            o.check = 3;
                    else
                        o.rewardCount = 0;
                        drop = 0;
                    end
                end

                if abs(o.hProbe.position(1) - o.S.centerPix(1)) < abs(o.checkpoints(3)) 
                    o.checkpointTimes(3) = GetSecs;
                    o.checkpointFlags(3) = 1;
                    
                    if o.rewardCount < o.P.rewardNumber(1) && o.check==3
                            o.rewardCount = o.rewardCount + 1;
                            drop = 1;
                            o.rewardTimes(3) = GetSecs;
                            o.check =4;
                    else
                        o.rewardCount = 0;
                        drop = 0;
                    end
                end

                % *** state updates
                if abs(o.hProbe.position(1)  - o.S.centerPix(1)) < abs(o.P.MotionAccepBound)
                    o.responseEnd = GetSecs;
                    o.checkpointTimes(4) = GetSecs;
                    o.checkpointFlags(4) = 1;
                    o.hProbe.position(1) = o.S.centerPix(1);
                    o.state = 4;
                    o.error = 0;
                end

            elseif abs(o.hProbe.position(1) - o.S.centerPix(1)) >= abs(o.P.bound)%(1) || o.hProbe.position(1) <= o.P.bound(2)
                
                o.state = 4;
                o.error = 3; % Error 3 out of bound/wrong direction
                o.responseEnd = GetSecs;
                %o.itiStart = GetSecs;
            end

        elseif o.state == 3 && currentTime > o.stimStart + o.P.noresponseDur
            o.error = 4; % time out
            o.state = 4;
            o.responseEnd = GetSecs;
        end


        %%%%% STATE 4 -- STIMULUS HOLD %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % If the stimulus gets to the center or the bounds
        if o.state == 4 && currentTime > o.responseEnd + o.P.stimHold(1) && o.error == 0
            o.hProbe.position(1) = o.S.centerPix(1);
            
            o.state = 7; % 
            o.itiStart = GetSecs;
        elseif o.state == 4  && o.error == 3
            if currentTime > o.responseEnd + o.P.stimHold(2)
                o.state = 9;
                o.itiStart = GetSecs;
            else
                o.hProbe.position(1) = o.S.centerPix(1) + 2.*round(o.P.stimPos(1)*o.S.pixPerDeg);
                o.RunMoErrorSound = 1;
                
            end
        elseif o.state == 4 && o.error == 4
            if currentTime > o.responseEnd + o.P.stimHold(2)
            
            o.state = 9; % no reward 
            o.itiStart = GetSecs;
            else
                o.hProbe.transparent = 0;
            end

        end
        

        %%%%% STATE 7 -- INTER-TRIAL INTERVAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Deliver rewards for correct trials 
        if o.state == 7 
            if o.error == 0 && o.rewardCount < o.P.rewardNumber(2)
               if currentTime > o.itiStart + 0.2*o.rewardCount % deliver in 200 ms increments
                   o.rewardCount = o.rewardCount + 1;
                   drop = 1;
                   o.rewardTimes(4) = GetSecs;
          
               end
            
            else
                o.state = 9;
                
               
            end
        end
        %******* fixation break feedback, but otherwise go to state 9
        if o.state == 8
               if currentTime > o.itiStart + 0.2   % enough time to flash fix break 
                  o.state = 9; 
                  if o.error 
                     %o.Iti = o.P.iti + o.P.blank_iti;
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

            case 3                
                % fixation remains on while Gabor stim is shown
                %********* show stimulus
                if ( currentTime < o.stimStart + o.P.stimDur )
                    o.hProbe.beforeFrame();
                end
                %************
                o.hFix.beforeFrame(1);

            case 4    % disappear fixation and show apertures to go

                    o.hProbe.beforeFrame(); %just show the probe - static 
                
            case 7 % iti - reward 
                if o.error == 0
                    o.Faces.beforeFrame();

                    o.RunRewardSound =1;
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
        if (o.RunFixBreakSound == 1) && (o.NeverBreakSoundTwice == 0)  
           sound(o.fixbreak_sound,o.fixbreak_sound_fs);
           o.NeverBreakSoundTwice = 1;
        end
        if (o.RunMoErrorSound == 1) && (o.NeverMoErrorSoundTwice == 0)  
           sound(o.motionerror_sound,o.motionerror_sound_fs);
           o.NeverMoErrorSoundTwice = 1;
        end
        if (o.RunFixBreakSound == 1) && (o.NeverBreakSoundTwice == 0)  
           sound(o.fixbreak_sound,o.fixbreak_sound_fs);
           o.NeverBreakSoundTwice = 1;
        end

        %**************************************************************
    end
   
    function Iti = end_run_trial(o)
        Iti = o.Iti - (GetSecs - o.itiStart); % returns generic Iti interval
    end
    
    function plot_trace(o,handles)
        %****** plot eccentric ring where stimuli appear
%         h = handles.EyeTrace;
%         set(h,'NextPlot','Replace');
%         eyeRad = handles.eyeTraceRadius;
%         % Target ring
%         r = o.P.stimEcc;
%         plot(h,r*cos(0:.01:1*2*pi),r*sin(0:.01:1*2*pi),'-k');
%         set(h,'NextPlot','Add');
%         %********** plot where all target hits occured
%         for k = 1:o.FixCount
%            r = o.P.fixRadius;
%            xx = o.FixHit(1,k);
%            yy = o.FixHit(2,k);
%            plot(h,xx + r*cos(0:.01:1*2*pi),yy + r*sin(0:.01:1*2*pi),'-m');
%         end
%         %*****************
%         axis(h,[-eyeRad eyeRad -eyeRad eyeRad]);
    end
    
    function PR = end_plots(o,P,A)   %update D struct if passing back info
      %************* STORE DATA to PR
        PR = struct;
        PR.error = o.error;
        PR.contrast = o.P.contrast;
        PR.stimPos = o.P.stimPos;

        PR.checkpoints = o.checkpoints;
        PR.checkpointsPer = o.P.checkpoints;
        PR.checkpointFlags = o.checkpointFlags;

        PR.fixStart = o.fixStart;
        PR.stimStart = o.stimStart;
        PR.responseStart = o.responseStart;
        PR.responseEnd = o.responseEnd;
        PR.responseTime = o.responseEnd - o.responseStart;
        PR.checkpointTimes = o.checkpointTimes;
        PR.rewardTimes = o.rewardTimes;

        PR.fixDur = o.fixDur;
        
      
        %******* this is also where you could store Gabor Flash Info
        
        %%%% Record some data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        o.D.error(A.j) = o.error;
        
        o.D.cpd(A.j) = P.cpd;

        %%%% Plot results %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Dataplot 1, errors
        errors = [0 1 2 3 4 5;
            sum(o.D.error==0) sum(o.D.error==1) sum(o.D.error==2) sum(o.D.error==3) sum(o.D.error==4) sum(o.D.error==5)];
%         bar(o.DataPlot1,errors(1,:),errors(2,:));
%         title(o.DataPlot1,'Errors');
%         ylabel(o.DataPlot1,'Count');
%         set(o.DataPlot1,'XLim',[-.75 5.75]);

        % DataPlot2, fraction correct by spatial location (left or right trial)
        % Note that this plot will break down if multiple stimulus eccentricities 
        % or a non horizontal hexagon are used. It will also only calculate
        % fraction correct for locations assigned by the trials list.
%         locs = unique(o.trialsList(:,1:2),'rows');
%         nlocs = size(locs,1);
%         labels = cell(1,nlocs);
%         fcXxy = zeros(1,nlocs);
%         for i = 1:nlocs
%             x = locs(i,1); y = locs(i,2);
%             Ncorrect = sum(o.D.x == x & o.D.y == y & o.D.error == 0);
%             Ntotal = sum(o.D.x == x & o.D.y == y & (o.D.error == 0 | o.D.error > 2.5));
%             if  Ntotal > 0
%                 fcXxy(i) = Ncorrect/Ntotal;
%             end
%             % Constructs labels based on the six locations
%             if x > 0 && abs(y) < .01;       labels{i} = 'R';    end
%             if x < 0 && abs(y) < .01;       labels{i} = 'L';    end
%           end
%         bar(A.DataPlot2,1:nlocs,fcXxy);
%         title(A.DataPlot2,'By Location');
%         ylabel(A.DataPlot2,'Fraction Correct');
%         set(A.DataPlot2,'XTickLabel',labels);
%         axis(A.DataPlot2,[.25 nlocs+.75 0 1]);
% 
%         % Dataplot3, fraction correct by cycles per degree
%         % This plot only calculates the fraction correct for trials list cpds.
%         cpds = unique(o.trialsList(:,3));
%         ncpds = size(cpds,1);
%         fcXcpd = zeros(1,ncpds);
%         labels = cell(1,ncpds);
%         for i = 1:ncpds
%             cpd = cpds(i);
%             Ncorrect = sum(o.D.cpd == cpd & o.D.error == 0);
%             Ntotal = sum(o.D.cpd == cpd & (o.D.error == 0 | o.D.error > 2.5));
%             if Ntotal > 0
%                 fcXcpd(i) = Ncorrect/Ntotal;
%             end
%             labels{i} = num2str(round(cpd)); %num2str(round(10*cpd)/10);
%         end
%         bar(A.DataPlot3,1:ncpds,fcXcpd);
%         title(A.DataPlot3,'By Cycles per Degree');
%         ylabel(A.DataPlot3,'Fraction Corret');
%         set(A.DataPlot3,'XTickLabel',labels);
%         axis(A.DataPlot3,[.25 ncpds+.75 0 1]);
      
    end
    
  end % methods
    
end % classdef
