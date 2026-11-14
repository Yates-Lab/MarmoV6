%% protocol for Dotsflow_dirRev 
% Last Modification: Apr 07, 2025 - PSC 

classdef PR_DotsflowDirectionRev < handle
  % Matlab class for running an experimental protocl
  % The class constructor can be called with a range of arguments:
  
  properties (Access = public), 
       
       startTime double = 0; % trial start time = stimStart 
       endTime double   = 0; % trial end time = stimEnd        
       rewardCount double = 0;    % counter for reward drops
       FrameCount double = 0;
       MaxFrame double = 36*240+10;
       FlowHistory double = [];
       modd double =0;
       d double =1;
              
  end
      
  properties (Access = private)
    winPtr; % ptb window
    state double = 0;      % state counter
    error double = 0;      % error state in trial
    S;      % copy of Settings struct (loaded per trial start)
    P;      % copy of Params struct (loaded per trial)
    trialsList; % a list of trials to run in the experiment 
    trialIndexer = [];

    %********* stimulus structs for use
    hFlow = []        % object for Dots flow 
    
    %**************** PR data struct for end plots stats 
    D struct = struct;        
  end
  
  methods (Access = public)
      function o = PR_DotsflowDirectionRev(winPtr)
      o.winPtr = winPtr; 
      o.trialsList = [];
    end
    
    function state = get_state(o)
        state = o.state;
    end
    
    function initFunc(o,S,P)

        %********** Set-up for trial indexing (required) 
        o.error = 0;
%        o.trialIndexer = marmoview.TrialIndexer(o.trialsList,P);
 
         %********** Initialize Graphics Objects
         o.hFlow = stimuli.dotspatial_dir(o.winPtr);   % dots flow stimulus
         o.FlowHistory = zeros(o.MaxFrame,10,P.numDots);
         
    end
   
    function closeFunc(o)
        o.hFlow.CloseUp();
       
    end
   
    function generate_trialsList(o,S,P)
           % nothing for this protocol
           
            % Generate trials list - just the trial index for this protocol
            o.trialsList = [1:S.finish];
            
    end
    
    function P = next_trial(o,S,P)
          %********************
          o.S = S;
          o.P = P;       
          %*******************
        
          if P.runType == 1   % go through trials list    
                %i = o.trialIndexer.getNextTrial(o.error);
                %****** update trial parameters for next trial
              
                %******************
                o.P = P;  % set to most current
          end
          
         

          % Make dots flow stimulus texture (?)
            o.hFlow.size = P.size;
            o.hFlow.speed = P.speed;
            o.hFlow.direction = P.direction;
            o.hFlow.numDots = P.numDots;
            o.hFlow.lifetime = P.lifetime;
            o.hFlow.maxRadius = P.maxRadius;
            o.hFlow.position = P.position;
            o.hFlow.color = P.color;
            o.hFlow.pixPerDeg = S.pixPerDeg;
            o.hFlow.dotType = P.dotType;
            o.hFlow.refreshRate = P.refreshRate;

          %******************************************
    end
    
    function [FP TS] = prep_run_trial(o)
        
          %********VARIABLES USED IN RUNNING TRIAL LOGISTICS
          
          % rewardCount counts the number of juice pulses, 1 delivered per frame
          o.rewardCount = 0;
            
          % Setup the state
          o.state = 0; % Showing the dots flow 
          o.error = 0; % Start with error as 0 - no error 
          
          o.startTime = GetSecs;

          FP(1).states = [];  %before fixation
          
          %******* set which states are TimeSensitive, if [] then none
          TS = 0:1;  % all times during target presentation
          o.hFlow.beforeTrial();
    end
    
    function keepgoing = continue_run_trial(o,screenTime)
        keepgoing = 0;
        if (o.state < 1) % as the flow finishes its presentation, state turns to 1 from 0
            keepgoing = 1;
        end
    end
   
    %******************** THIS IS THE BIG FUNCTION *************
    function drop = state_and_screen_update(o,currentTime,x,y,varargin) 
        drop = 0;
        %******* THIS PART CHANGES WITH EACH PROTOCOL ****************
        
        %%%%% STATE 0 -- GET INTO THE DOTS FLOW PRESENTATION %%%%%%%
        % STATE SPECIFIC DRAWS

        % calculate x & y-shift based on direction condition and time 
        
        
        if o.state == 0 && currentTime < o.startTime + o.P.trialdur
            

            o.hFlow.beforeFrame();

            fc = 0;
            if o.FrameCount>0; fc=1;end 
            
            hdx=0;hdy=0;

            if o.FrameCount==0
                o.d = 1;
            else
                o.d = ceil(o.FrameCount./(240*1.5));
            end 
            d=12-floor((o.startTime + o.P.trialdur - currentTime)./1.5);

            
          
            o.modd = mod((o.FrameCount),(240*1.5));
                      

        if o.d<=24
            move =1;
            flowDir = o.P.direction(o.d);
            % hypothetical dx & hypothetical dy before converted to
            % x- y-shift (which are the dx dy inputs in dospatial_dir)
            if (flowDir>0 && flowDir<90) || (flowDir>90 && flowDir<180)
                hdx = 1;
                hdy = 1./(tan(deg2rad(flowDir)));
                scale = 1./sqrt(hdx^2 + hdy^2);
                hdx = scale*hdx;
                hdy = scale*hdy;
            elseif (flowDir>180 && flowDir<270) || (flowDir>270 && flowDir<360)
                hdx = -1;
                hdy = -(1./(tan(deg2rad(flowDir))));
                scale = 1./sqrt(hdx^2 + hdy^2);
                hdx = scale*hdx;
                hdy = scale*hdy;
            elseif flowDir == 0
                hdx = 0;
                hdy = 1;
            elseif flowDir == 90
                hdx = 1;
                hdy = 0;
            elseif flowDir == 180
                hdx = 0;
                hdy = -1;
            elseif flowDir == 270
                hdx = -1;
                hdy = 0;
            end
        end
        xshift = hdx * (o.hFlow.speed * 1./(o.hFlow.refreshRate) * o.hFlow.pixPerDeg); 
        % -o.P.speed * 1./(o.P.refreshRate) * obj.pixPerDeg
        yshift = hdy * (o.hFlow.speed * 1./(o.hFlow.refreshRate) * o.hFlow.pixPerDeg);

        if o.d>24
            xshift=0;
            yshift=0;
            move =0;
        end 


            o.hFlow.afterFrame(xshift, yshift,o.modd,fc);

            o.FrameCount = o.FrameCount + 1;

           
            
            % NOTE: store screen time in "continue_run_trial" after flip
            o.FlowHistory(o.FrameCount,1,:) = o.hFlow.x;  % store x
            o.FlowHistory(o.FrameCount,2,:) = o.hFlow.y;  % store y
            o.FlowHistory(o.FrameCount,3:5,:) = o.hFlow.color;
            o.FlowHistory(o.FrameCount,6,:) = o.modd;
            o.FlowHistory(o.FrameCount,7,:) = o.d;
            o.FlowHistory(o.FrameCount,8,:) = currentTime;
            o.FlowHistory(o.FrameCount,9,:) = flowDir;
            o.FlowHistory(o.FrameCount,10,:) = move;
                     
                     
        end 

        if o.state == 0 && currentTime > o.startTime + o.P.trialdur
            o.state = 1; % Move to iti -- inter-trial interval
            o.error = 0; % Error 1 is failure to initiate
            o.FrameCount = 0; % reset the frame count 
            o.rewardCount = o.rewardCount + 1;
            drop = 1;
            o.endTime = GetSecs;
        end
          
        % %% PHOTODIODE FLASH, move to frame control(?)
%         %DPR - 5/5/2023
        if isfield(o.S,'photodiode')
            if rem(o.FrameCount,o.S.frameRate/o.S.photodiode.TF)==1 % first frame flash photodiode
                Screen('FillRect',o.winPtr,o.S.photodiode.flash,o.S.photodiode.rect)
            else
                Screen('FillRect',o.winPtr,o.S.photodiode.init,o.S.photodiode.rect)
            end
       % disp(rem(o.FrameCount,o.S.frameRate/o.S.photodiode.TF))
        end
       
        %**************************************************************
    end
    
    
    function Iti = end_run_trial(o)
        Iti = 0.5; % returns generic Iti interval
    end
    
    function plot_trace(o,handles)
        % This function plots the eye trace from a trial in the EyeTracker
        % window of MarmoView.

        
    end
    
    function PR = end_plots(o,P,A)   %update D struct if passing back info
        
        %************* STORE DATA to PR
        PR = struct;
        PR.error = o.error;
        PR.FlowHistory = o.FlowHistory;
        PR.startTime = o.startTime;
        PR.endTime = o.endTime;
        
        %******* this is also where you could store Gabor Flash Info
        
        %%%% Record some data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        o.D.error(A.j) = o.error;
        
    end
    
  end % methods
    
end % classdef
