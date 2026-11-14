classdef PR_OKN_converging < protocols.protocol
    % Stimuli for OKN reflex in mouse and marmoset, for determining the 
    % location of the preferred retinal locus in terms of its projection 
    % into the visual field. Hypothesis is that the OKN should be nulled 
    % at this location. 

    % Stim types:
    % 1 -> Converging optic flow
    % 2 -> 1D square waves, 
    % 3 -> 1D square waves with perspective
    % 4 -> Bullseye

    % This stimulus doesn't have probes, in some ways its most like facecal

  properties (Access = public)   
       itiStart double = 0;        % start of iti interval
%        rewardCount double = 0;     % counter for reward drops
%        rewardGap double = 0;       % gap for next target onset
%        rewardTime double = 0;      % store time of last reward
  end
      
  properties (Access = public) % grant access to all protocol objects
%     winPtr % ptb window
%     state double = 0      % state counter
%     error double = 0      % error state in trial
%     %************
%     S       % copy of Settings struct (loaded per trial start)
%     P       % copy of Params struct (loaded per trial)
%     %********* stimulus structs for use
    trialsList=[];
    stimtype  = 2   %Initialise to square waves 
    FrameCount = 0
    MaxFrame = [];
    TrialDur = 0;
    hStim =[];
    % Will need to add noisetype specific stimuli
    StimHistory=[];
    %******** parameters for positioning stimuli
    PosList = []      % will be x,y positions of stimuli
    MovList = []      % speed vector if a moving item
    %**** Photodiode flash timing
    Flashtime = [];
    FlashOutTimings = [];
    %**********************************
    D struct = struct()        % store PR data for end plot stats, will store dotmotion array
  end
  
  methods (Access = public)
    function o = PR_OKN_converging(winPtr)
        o = o@protocols.protocol(winPtr);
    end
    

    % initialization called 
    function initFunc(o,S,P)

       %********** Set-up for trial indexing (required) 
       cors = [0,4];  % count these errors as correct trials
       reps = [1,2];  % count these errors like aborts, repeat
       o.trialsList = [];  % empty for this protocol
       %**********
      
       %******* init Noise History with MaxDuration **************
       o.MaxFrame = ceil(20*S.frameRate);
       o.StimHistory = zeros(o.MaxFrame,9);  % x,y,ori,fixated
       

       %******* SETUP NOISE BASED ON TYPE, HARTLEY, SPATIAL, ETC
       o.stimtype = P.stimtype;
       %**********
       
       %set up all stimuli
       %o.Stim = stimuli.X(o.winPtr,'bkgd',S.bgColour,'gray');  
       switch o.stimtype
           case 0 % Fullscreen square wave, standard OKN
               o.StimHistory = nan(o.MaxFrame,7); % time, orientation, cpd, phase, direction, speed, contrast
               
               % position
               x = P.GratCtrX*S.pixPerDeg + S.centerPix(1);
               y = -P.GratCtrY*S.pixPerDeg + S.centerPix(2);
               
               % noise object is created here
               o.hStim = stimuli.sq_grating_drifting(o.winPtr, ...
                    'numDirections', P.numDir, ...
                    'minSF', P.GratSFmin, ...
                    'numOctaves', P.GratNumOct, ...
                    'pixPerDeg', S.pixPerDeg, ...
                    'frameRate', S.frameRate, ...
                    'speeds', P.GratSpeed, ...
                    'position', [x y], ...
                    'screenRect', S.screenRect, ...
                    'diameter', P.GratDiameter, ...
                    'durationOn', P.GratDurOn, ...
                    'durationOff', P.GratDurOff, ...
                    'isiJitter', P.GratISIjit, ...
                    'contrasts', P.GratCon, ...
                    'randomizePhase', P.RandPhase);
                
               o.hStim.updateTextures(); % create the procedural texture

           case 1 % Converging optic flow
               % TODO DOTS
               o.StimNum = min(P.numDots, 100); % only store up to 500 dots
               o.StimHistory = nan(o.MaxFrame,(1+(o.StimNum * 2))); 
               % noise object is created here
               o.hStim = stimuli.dotspatialnoise(o.winPtr, 'numDots', P.numDots, ...
                   'sigma', P.noiseApertureSigma*S.pixPerDeg);
               o.hStim.contrast = P.noiseContrast;
               o.hStim.size = P.dotSize * S.pixPerDeg;
               o.hStim.speed = P.dotSpeedSigma * S.pixPerDeg / S.frameRate;
               o.hStim.updateEveryNFrames = ceil(S.frameRate / P.noiseFrameRate);
           
           case 2 % 1D square waves, mirrored pair 
               % TODO
              o.StimHistory = nan(o.MaxFrame,9); % time, orientation, cpd, phase, direction, speed, contrast, xpos, ypos
               
               % position
               x = P.GratCtrX*S.pixPerDeg + S.centerPix(1);
               y = -P.GratCtrY*S.pixPerDeg + S.centerPix(2);
               
               % noise object is created here
               o.hStim = stimuli.sq_mirror_grating_drifting(o.winPtr, ...
                    'numDirections', P.numDir, ...
                    'minSF', P.GratSFmin, ...
                    'numOctaves', P.GratNumOct, ...
                    'pixPerDeg', S.pixPerDeg, ...
                    'frameRate', S.frameRate, ...
                    'speeds', P.GratSpeed, ...
                    'position', [x y], ...
                    'screenRect', S.screenRect, ...
                    'diameter', P.GratDiameter, ...
                    'durationOn', S.frameRate*(P.trialdur+1), ...
                    'durationOff', 0, ...
                    'isiJitter', P.GratISIjit, ...
                    'contrasts', P.GratCon, ...
                    'randomizePhase', P.RandPhase);

               o.hStim.updateTextures(); % create the procedural texture

           case 3 % 1D square waves with perspective
               % TODO
%               o.StimHistory = nan(o.MaxFrame,7*2); % time, orientation, cpd, phase, direction, speed, contrast
%                
%                % position
%                x = P.GratCtrX*S.pixPerDeg + S.centerPix(1);
%                y = -P.GratCtrY*S.pixPerDeg + S.centerPix(2);
%                
%                % noise object is created here
%                o.hStim = stimuli.sq_mirror_grating_drifting(o.winPtr, ...
%                     'numDirections', P.numDir, ...
%                     'minSF', P.GratSFmin, ...
%                     'numOctaves', P.GratNumOct, ...
%                     'pixPerDeg', S.pixPerDeg, ...
%                     'frameRate', S.frameRate, ...
%                     'speeds', P.GratSpeed, ...
%                     'position', [x y], ...
%                     'screenRect', S.screenRect, ...
%                     'diameter', P.GratDiameter, ...
%                     'durationOn', P.GratDurOn, ...
%                     'durationOff', P.GratDurOff, ...
%                     'isiJitter', P.GratISIjit, ...
%                     'contrasts', P.GratCon, ...
%                     'randomizePhase', P.RandPhase);
%                 
%                 
%                o.hStim.updateTextures(); % create the procedural texture

           case 4 % Bullseye, concentric rings moving inward
               % TODO based on ret wedges
       end
    end

    function state = get_state(o)
        state = o.state;
    end

    function generate_trialsList(o,~,~)
           % nothing for the default. overload this function if you want to
           % generate a trial list,
           % 3x3 grid or 3 positions along axis
           o.trialsList = [];  %
    end
    
   
    function closeFunc(o)
        o.hStim.CloseUp();
    end

    function P = next_trial(o,S,P)
          %********************
          o.S = S;
          o.P = P;       
          %*******************
          o.error = 0;
          o.FrameCount = 0;
          o.Flashtime = [];
          o.FlashOutTimings = [];
          %********
          if (P.trialdur < 20)
              o.TrialDur = P.trialdur;
          else
              o.TrialDur = 20;
          end
        
         % Update position
           x = (o.P.GratCtrX + 1*round((rand(o.hStim.rng,1)*3+0.5)-2))*o.S.pixPerDeg + o.S.centerPix(1) ;
           y = -o.P.GratCtrY*o.S.pixPerDeg + o.S.centerPix(2);
           o.hStim.position=[x y];


    end
       
    function [FP,TS] = prep_run_trial(o)
        % Setup the state
        o.state = 0; % Showing the stimuli
        o.Iti = o.P.iti;   %#ok<*PROP> % set ITI interval from P struct stored in trial
        %*******
        FP(1).states = 0;  % any special plotting of states, 
        FP(1).col = 'b';   % FP(1).states = 1:2; FP(1).col = 'b';
                           % would show states 1,2 in blue for eye trace
        %******* set which states are TimeSensitive, if [] then none
        TS = 0;  % always sensitive states(?)
        %********
        o.startTime = GetSecs;
    end
    
 function updateStim(o,xx,yy,currentTime)
         if (o.FrameCount < o.MaxFrame)
             
             switch o.stimtype
                 case 0 %Sq wave
                  o.hStim.afterFrame(); % update parameters
                     if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                         Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                         o.hStim.beforeFrame(); % draw
                         Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                         o.hStim.beforeFrame(); % draw
                     else
                        o.hStim.beforeFrame(); % draw
                     end
                     %**********
                     o.FrameCount = o.FrameCount + 1;
                     % NOTE: store screen time in "continue_run_trial" after flip
                     o.StimHistory(o.FrameCount,2) = o.hStim.orientation;  % store orientation
                     o.StimHistory(o.FrameCount,3) = o.hStim.cpd;  % store spatialfrequency
                     o.StimHistory(o.FrameCount,4) = o.hStim.phase;
                     o.StimHistory(o.FrameCount,5) = o.hStim.orientation-90;
                     o.StimHistory(o.FrameCount,6) = o.hStim.speed;
                     o.StimHistory(o.FrameCount,7) = o.hStim.contrast;
                     
                     % time, orientation, cpd, phase, direction, speed, contrast

                 case 1 % Dots
                     o.hStim.afterFrame(); % update parameters
                     if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                         Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                         o.hStim.beforeFrame(); % draw
                         Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                         o.hStim.beforeFrame(); % draw
                     else
                        o.hStim.beforeFrame(); % draw
                     end
                     %**********
                     o.FrameCount = o.FrameCount + 1;
                     % NOTE: store screen time in "continue_run_trial" after flip
                     o.StimHistory(o.FrameCount,2:end) = [o.hStim.x(1:o.noiseNum) o.hStim.y(1:o.noiseNum)];  % xposition of first gabor
                 
                 case 2 %Sq wave

                  o.hStim.afterFrame(); % update parameters
                     if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                         Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                         o.hStim.beforeFrame(); % draw
                         Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                         o.hStim.beforeFrame(); % draw
                     else
                        o.hStim.beforeFrame(); % draw
                     end
                     %**********
                     o.FrameCount = o.FrameCount + 1;
                     % NOTE: store screen time in "continue_run_trial" after flip
                     o.StimHistory(o.FrameCount,2) = o.hStim.orientation;  % store orientation
                     o.StimHistory(o.FrameCount,3) = o.hStim.cpd;  % store spatialfrequency
                     o.StimHistory(o.FrameCount,4) = o.hStim.phase;
                     o.StimHistory(o.FrameCount,5) = o.hStim.orientation-90;
                     o.StimHistory(o.FrameCount,6) = o.hStim.speed;
                     o.StimHistory(o.FrameCount,7) = o.hStim.contrast;
                     o.StimHistory(o.FrameCount,8) = o.hStim.position(1);
                     o.StimHistory(o.FrameCount,9) = o.hStim.position(2);
%                      o.StimHistory(o.FrameCount,8) = o.hStim2.orientation;  % store orientation
%                      o.StimHistory(o.FrameCount,9) = o.hStim2.cpd;  % store spatialfrequency
%                      o.StimHistory(o.FrameCount,10) = o.hStim2.phase;
%                      o.StimHistory(o.FrameCount,11) = o.hStim2.orientation-90;
%                      o.StimHistory(o.FrameCount,12) = o.hStim2.speed;
%                      o.StimHistory(o.FrameCount,13) = o.hStim2.contrast;
                     % time, orientation, cpd, phase, direction, speed, contrast
                 case 3 %Sq wave vanishing
                     %TODO
                 case 4
                     %TODO
               
             end
            %****************
         end
    end    
    


    function keepgoing = continue_run_trial(o,screenTime)
        keepgoing = 0;
        if (o.state < 1)
            keepgoing = 1;
        end
        %******** this is also called post-screen flip, and thus
        %******** can be used to time-stamp any previous graphics calls
        %******** for object on the screen and things like that
        if (o.FrameCount)
           o.StimHistory(o.FrameCount,1) = screenTime;  %store screen flip 
        end
    end
   
    %******************** THIS IS THE BIG FUNCTION *************
    function drop = state_and_screen_update(o,currentTime,x,y,varargin)  
        drop = 0;
        outputs = {};
        if ~isempty(varargin) && length(varargin)>1
            outputs=varargin{2};
        end
        %******* THIS PART CHANGES WITH EACH PROTOCOL ****************
        if o.state == 0 && currentTime > o.startTime + o.P.trialdur
            o.state = 1; % Inter trial interval
            o.itiStart = GetSecs;
            drop = 1; % handles.reward.deliver();
        end

        % GET THE DISPLAY READY FOR THE NEXT FLIP
        % STATE SPECIFIC DRAWS
        % Always update the stimulus
        o.updateStim(NaN,NaN,currentTime);

        %**************************************************************
        



        [o.Flashtime,o.FlashOutTimings] = marmoview.updatePhotodiode( ...
            o.winPtr,o.S,outputs,o.FrameCount,currentTime,o.Flashtime,o.FlashOutTimings);

    end
    
    function Iti = end_run_trial(o)
        Iti = o.Iti;  % returns generic Iti interval (not task dep)
    end
    
    function plot_trace(o,handles)
        %********* append other things eye trace plots if you desire
%         h = handles.EyeTrace;
%         faceConfig = o.S.faceConfigs{o.P.faceConfig};
%         set(h,'NextPlot','Replace');
%         for i = 1:size(o.faceConfig,1)
%               xF = o.faceConfig(i,1);
%               yF = o.faceConfig(i,2);
%               rF = o.P.faceRadius;
%               plot(h,[xF-rF xF+rF xF+rF xF-rF xF-rF],[yF-rF yF-rF yF+rF yF+rF yF-rF],'-k');
%               if (i == 1)
%                 set(h,'NextPlot','Add');
%               end
%         end
        
    end
    
    function PR = end_plots(o,P,A)   %update D struct if passing back info     
       %************* STORE DATA to PR
        %**** NOTE, no need to copy anything from P itself, that is saved
        %**** already on each trial in data .... copy parts that are not
        %**** reflected in P at all and generated random per trial
        warning('off'); % suppress warning about converting to struct
        PR = struct(o); % convert the entire protocol to a struct
        warning('on'); % turn warnings back on
         
        if isa(o.hStim, 'stimuli.stimulus')
            PR.hStim = copy(o.hStim); % store noise object
        end

        PR.error = o.error;
        if o.FrameCount == 0
            PR.StimHistory = [];
        else
            PR.StimHistory = o.StimHistory(1:o.FrameCount,:);
        end

        %******* need to add a History for probe stimuli later
        
        PR.Flashtime = o.Flashtime;
        PR.FlashOutTimings = o.FlashOutTimings;
        %******* this is also where you could store Gabor Flash Info

        %%%% Record some data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% It is advised not to store things too large here, like eye movements, 
        %%%% that would be very inefficient as the experiment progresses
        
        %********** UPDATE ERROR, if Line Cue correct is standard
        o.D.error(A.j) = o.error;

        
       % Data plots go here
    end    
  end % methods
    
end % classdef
