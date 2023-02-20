function [S,P] = Training_IBL()

%%%% NECESSARY VARIABLES FOR GUI
%%%% IBL contrast sensitivity task settings - 02152023 PSC 
% Need to incorporate & check:
    % check points - DONE 
    % error & success - timing, output - DONE
    % audio files for different outcome - DONE 
        % add reward face since the reward audio is to low compare to the
        % pupm - DONE 
    % end session plots 
        % trials and conditions progress in time
        % session psychometric function 
        % possible eye traces rendering (?)
    % 
    % data storage - DONE
    % create diff files for diff subs - DONE 
    % wheel & rotary encoder - wait for MarmoV6
    % FLIR camera/eye link - wait for MarmoV6
    % Body camera - wait for MarmoV6 

%%
% LOAD THE RIG SETTINGS, THESE HOLD CRUCIAL VARIABLES SPECIFIC TO THE RIG,
% IF A CHANGE IS MADE TO THE RIG, CHANGE THE RIG SETTINGS FUNCTION IN
% SUPPORT FUNCTIONS
S = MarmoViewRigSettings;

% NOTE THE MARMOVIEW VERSION USED FOR THIS SETTINGS FILE, IF AN ERROR, IT
% MIGHT BE A VERSION PROBLEM
S.MarmoViewVersion = '5';

% PARAMETER DESCRIBING TRIAL NUMBER TO STOP TASK
S.finish = 400;

% PROTOCOL PREFIX
S.protocol = 'IBLContrastGabor';
% PROTOCOL PREFIXS
S.protocol_class = ['protocols.PR_',S.protocol];


%NOTE: in MarmoView5 subject is entered in GUI

%******** Don't allow in trial calibration for this one (comment out)
% P.InTrialCalib = 1;
% S.InTrialCalib = 'Eye Calib in Trials';
S.TimeSensitive = 1:5;

% STORE EYE POSITION DATA
S.EyeDump = true;

% Define Banner text to identify the experimental protocol
% recommend maximum of ~28 characters
S.protocolTitle = 'IBL Contrast Sensitivity';

%%%%% END OF NECESSARY VARIABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%% PARAMETERS -- VARIABLES FOR TASK, CAN CHANGE WHILE RUNNING %%%%%%%%%
% INCLUDES STIMULUS PARAMETERS, DURATIONS, FLAGS FOR TASK OPTIONS
% MUST BE SINGLE VALUE, NUMERIC -- NO STRINGS OR ARRAYS!
% THEY ALSO MUST INCLUDE DESCRIPTION OF THE VALUE IN THE SETTINGS ARRAY

Screen('Preference', 'SkipSyncTests', 1);
P.faceTime = 0.1;
S.faceTime = 'Reward face time';
P.faceradius = 3;
S.faceradius = 'Reward face radius';

P.repeats = 20; % repeats per condition  
S.repeats = 'Number of repeats per condition:';
% Reward setting
P.rewardNumber = [1, 4];   % Max juice, only one drop ... it is so easy!
S.rewardNumber = 'Number of juice pulses to deliver:';

%********PENNY CODDING***********%
% Stimulus settings
P.ecc = 10;  % eccentricity of the grating at the trial start 
S.ecc = 'Grating eccentricity (dva):';
P.cpd = 2; % reference to human CSF @ peak contrst sensitivity 
S.cpd = 'Cycles per degree:';
P.FreqNum = 1;
S.FreqNum = 'Numb of freqs:';

P.contrast = 0.10;
S.contrast = 'CHECK IF USED!';
P.minContrast = 0;
S.minContrast = 'Min contrast to test';
P.maxContrast = 1;
S.maxcontrast = 'Max contrast to test';
P.ContrastNum = 10;
S.ContrastNum = 'Number of contrast levels';

P.xDeg = 0.0; 
S.xDeg = 'X center of stimulus (degrees):';
P.yDeg = 0.0;
S.yDeg = 'Y center of stimulus (degrees):';
P.radius = 3.0;   
S.radius = 'Grating radius (degrees):';

P.orientation = 0;
S.orientation = 'Orientation of grating (degrees):';
P.bkgd = 127;
S.bkgd = 'Choose a grating background color (0-255):';
P.range = 127;
S.range = 'Luminance range of grating (1-127):';
P.phase = -1;
S.phase = 'Grating phase (-1 or 1):';
P.squareWave = 0;
S.squareWave = '0 - sine wave, 1 - square wave';

% Gaze indicator
P.eyeRadius = 1.5; 
S.eyeRadius = 'Gaze indicator radius (degrees):';
P.eyeIntensity = 5;
S.eyeIntensity = 'Indicator intensity:';
P.showEye = 0;
S.showEye = 'Show the gaze indicator? (0 or 1):';

%****** fixation properties
P.fixPointRadius = 0.35; 
S.fixPointRadius = 'Fix Point Radius (degs):';
P.fixPointColorOut = 0;
S.fixPointColorOut = 'Color of point outline (0-255):';
P.fixPointColorIn = 255;
S.fixPointColorIn = 'Color of point center (0-255):';
P.xFixDeg = 0.0; 
S.xFixDeg = 'Fix X center (degs):';
P.yFixDeg = 0.0;
S.yFixDeg = 'Fix Y center (degs):';
% Fixation and Response Windows
P.initWinRadius = 100000;%1 %(skip)
S.initWinRadius = 'Enter to initiate fixation (deg):';
P.fixWinRadius = 100000;%2.0; %1.5;
S.fixWinRadius = 'Fixation window radius (deg):';

% Trial timing
    % fixation
P.startDur = 4;
S.startDur = 'Wait time to enter fixation (s):';
P.flashFrameLength = 30; %flash fixatin to draw animal to center
S.flashFrameLength = 'Length of fixation flash (frames):';
P.fixGrace = 0.05;
S.fixGrace = 'Grace period to be inside fix window (s):';
P.fixMin = 0.2;
S.fixMin = 'Minimum fixation (s):';
P.fixRan = 0.2; 
S.fixRan = 'Random additional fixation (s):';
    % stimulus 
P.stimDur = 10;
S.stimDur = 'Duration of grating presentation (s):';
P.stimHold = [0.5, 2]; % (0.5) - correct, (2) error - probably change the stim for success to marmie faces 
S.stimHold = 'Duration to hold stimulus on screen (s):'; % [Correct, incorrect||timeout]
P.noresponseDur = P.stimDur; %the same as stimDur 
S.noresponseDur = 'Duration to count error if no response(s):';

P.iti = 0.5;
S.iti = 'Duration of intertrial interval (s):';
% P.blank_iti = 1;
% S.blank_iti = 'Duration of blank intertrial(s):';
P.timeOut = 2;
S.timeOut = 'Time out for error (s):';

P.runType = 1; % follow the randomized trialslist 
S.runType = '0-User,1-Trials List:';

P.RepeatUntilCorrect = 1;
%**********CHANGE END**************%




