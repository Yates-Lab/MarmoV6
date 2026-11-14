%% protocol for Dotsflow_dirRandom 

classdef PR_Dotsflow_MTImaging < handle
  % Matlab class for running an experimental protocl
  % The class constructor can be called with a range of arguments:
  
  properties (Access = public), 
        Iti double = 10;
        itiStart double = 0;        % start of iti interval
       startTime double = 0; % trial start time = stimStart 
       endTime double   = 0; % trial end time = stimEnd        
       rewardCount double = 0;    % counter for reward drops
       FrameCount double = 0;
       MaxFrame double = 10*240+2; %24*240+2
       FlowHistory double = [];
       Flashtime = [];
              
  end
      
  properties (Access = private)
    winPtr; % ptb window
    state double = 0;      % state counter
    error double = 0;      % error state in trial
    S;      % copy of Settings struct (loaded per trial start)
    P;      % copy of Params struct (loaded per trial)
    trialsList; % a list of trials to run in the experiment 
    trialIndexer = [];
    stimEnds = [];
    grayEnds = [];
    cycleTime =[];
    flowSign = 1;
    init=0;

    %********* stimulus structs for use
    hFlow = []        % object for Dots flow 
    
    %**************** PR data struct for end plots stats 
    D struct = struct;        
  end
  
  methods (Access = public)
      function o = PR_Dotsflow_MTImaging(winPtr)
          o.winPtr = winPtr;
          o.trialsList = [];
      end

      function state = get_state(o)
          state = o.state;
      end

      function generate_trialsList(o,S,P)          
            % Generate trials list - just the trial index for this protocol
            o.trialsList = [1:S.finish];
            
    end
    
    function initFunc(o,S,P)

        %********** Set-up for trial indexing (required) 
        cors = [0];  % count these errors as correct trials
       reps = [1:7];  % count these errors like aborts, repeat
       if (~isempty(o.trialsList))
         o.trialIndexer = marmoview.TrialIndexer(o.trialsList,P,cors,reps);
       else
         disp('Error generating proper trialsList .... check function');
       end
       o.error = 0;
        
 
         %********** Initialize Graphics Objects
         o.hFlow = stimuli.dotspatial_MTImaging(o.winPtr);   % dots flow stimulus
         o.FlowHistory = zeros(o.MaxFrame,10,P.numDots);
         
    end
   
    function closeFunc(o)
        o.hFlow.CloseUp();
       
    end
   
    
    
    function P = next_trial(o,S,P)
          %********************
          o.S = S;
          o.P = P;
          o.Flashtime = [];
          %*******************
        
          if P.runType == 1   % go through trials list    
                i = o.trialIndexer.getNextTrial(o.error);
                     %***************
                     P.dirSeq = o.trialsList(i,:);
                     
                     %******************
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
          o.stimEnds = o.P.stimEnds;
          o.grayEnds = o.P.grayEnds;
          o.cycleTime = o.P.cycleTime;
          o.init = 0;
          o.Iti = o.P.iti; 

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
        outputs = {};
        if length(varargin)>1
            outputs = varargin{2};
        end
        %******* THIS PART CHANGES WITH EACH PROTOCOL ****************

        %%%%% STATE 0 -- GET INTO THE DOTS FLOW PRESENTATION %%%%%%%
        % STATE SPECIFIC DRAWS

        % calculate x & y-shift based on direction condition and time


        if o.state == 0 && currentTime < o.startTime + o.P.trialdur
            inputs=varargin{:};
            xshift = 0;
            yshift = 0; 
            flowsign = 0;
            for i =1:length(o.stimEnds)
                if (currentTime-o.startTime)<=o.cycleTime(o.stimEnds(i))&&(currentTime-o.startTime)...
                        >=o.cycleTime(o.stimEnds(i)-1)

                    o.hFlow.beforeFrame();
                    if mod(i,2)==0
                        flowsign = 1;
                    elseif mod(i,2)==1
                        flowsign =-1;
                    end 

                    if o.FrameCount ==0
                        o.init =1;
                    elseif abs(flowsign+o.FlowHistory(o.FrameCount,6,1))==1
                        o.init=1;
                    else
                        o.init=0;
                    end  

                    o.hFlow.afterFrame(xshift, yshift,flowsign,o.init);

                end
            end


            o.FrameCount = o.FrameCount + 1;
            % NOTE: store screen time in "continue_run_trial" after flip
            o.FlowHistory(o.FrameCount,1,:) = o.hFlow.x;  % store x
            o.FlowHistory(o.FrameCount,2,:) = o.hFlow.y;  % store y
            o.FlowHistory(o.FrameCount,3:5,:) = o.hFlow.color;
            o.FlowHistory(o.FrameCount,6,:) = flowsign;
            o.FlowHistory(o.FrameCount,7,:) = o.init;

            %**************************************************************
        end

        if o.state == 0 && currentTime > o.startTime + o.P.trialdur
            o.state = 1; % Move to iti -- inter-trial interval
            o.error = 0; % Error 1 is failure to initiate
            o.FrameCount = 0; % reset the frame count
            o.rewardCount = o.rewardCount + 1;
            drop = 1;
            o.endTime = GetSecs;
            o.itiStart = GetSecs;
        end
        %%%%%%% PHOTODIODE
        o.Flashtime = marmoview.updatePhotodiode(o.winPtr,o.S,outputs,o.FrameCount,currentTime,o.Flashtime);

        
    end 
    
    
    function Iti = end_run_trial(o)
        Iti = o.Iti - (GetSecs - o.itiStart); % returns generic Iti interval
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
        PR.Flashtime = o.Flashtime;
        %******* this is also where you could store Gabor Flash Info
        
        %%%% Record some data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        o.D.error(A.j) = o.error;
        
    end
    
  end % methods
    
end % classdef
