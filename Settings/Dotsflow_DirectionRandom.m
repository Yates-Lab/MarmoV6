
function [S,P] = Dotsflow_DirectionRandom()
% Settings for DotsflowDirectionRand
% Last Modification: Apr 23, 2025 - PSC
% size = 35pix @ 50cm VD 

%%%% NECESSARY VARIABLES FOR GUI
%%%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% LOAD THE RIG SETTINGS, THESE HOLD CRUCIAL VARIABLES SPECIFIC TO THE RIG,
% IF A CHANGE IS MADE TO THE RIG, CHANGE THE RIG SETTINGS FUNCTION IN
% SUPPORT FUNCTIONS
S = MarmoViewRigSettings;

% NOTE THE MARMOVIEW VERSION USED FOR THIS SETTINGS FILE, IF AN ERROR, IT
% MIGHT BE A VERSION PROBLEM
S.MarmoViewVersion = '6';

% PARAMETER DESCRIBING TRIAL NUMBER TO STOP TASK
S.finish = 80; % 

% PROTOCOL PREFIX
S.protocol = 'DotsflowDirectionRand';
% PROTOCOL PREFIXS
S.protocol_class = ['protocols.PR_',S.protocol];


%NOTE: in MarmoView5 subject is entered in GUI

%******** Don't allow in trial calibration for this one (comment out)
% P.InTrialCalib = 1;
% S.InTrialCalib = 'Eye Calib in Trials';
S.TimeSensitive = 1:7;

% STORE EYE POSITION DATA
% S.EyeDump = false;

% Define Banner text to identify the experimental protocol
% recommend maximum of ~28 characters
S.protocolTitle = 'Random Direction Flow field at Imaging Rig';

%%%%% END OF NECESSARY VARIABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%% PARAMETERS -- VARIABLES FOR TASK, CAN CHANGE WHILE RUNNING %%%%%%%%%
% INCLUDES STIMULUS PARAMETERS, DURATIONS, FLAGS FOR TASK OPTIONS
% MUST BE SINGLE VALUE, NUMERIC -- NO STRINGS OR ARRAYS!
% THEY ALSO MUST INCLUDE DESCRIPTION OF THE VALUE IN THE SETTINGS ARRAY

% Reward setting
% P.rewardNumber = 1;   % Max juice, only one drop ... it is so easy!
% S.rewardNumber = 'Number of juice pulses to deliver:';



%************** stimulus settings 

P.size = 35;
S.size = 'Dot size (pix)'; % 0.8434 visual deg @ 50cm vd, 0.91@45cm  
P.speed = 16;
S.speed = 'Dot motion speed for passive viewing (deg/s)';

P.dirStep = 30;
S.dirStep = 'step size of direction stimuli (deg)';
P.direction = [0:P.dirStep:(360-P.dirStep)];
S.direction = 'Initialized dots direction (deg)';
P.ndirs = length(P.direction);
S.ndirs = 'number of directions';

P.numDots = 150;
S.numDots = 'Number of dots';
P.lifetime = Inf;
S.lifetime = 'Lifetime of the dots (frames)';
P.maxRadius = 40;
S.maxRadius = 'Maximum radius of the dots';
P.position = S.screenRect(3:4).*0.5;
S.position = 'Origin position in draw dots function';
P.color  = [0 0 0];
S.color = 'Color of the dots';
P.contrast = 0.5;
S.contrast = 'Contrast of the dots';
P.dotType = 1;
S.dotType = 'Type of the dots';

P.runType = 1;
S.runType = '0-User,1-Trials List:';

%******* trial timing and reward
P.trialdur = 2.0*12;%0.5+(1.5+0.5)*12; % this is also the stimulus duration 
S.trialdur = 'Trial/Dots Flow Duration (s):';
P.refreshRate = 240;
S.refreshRate = 'Stimulus refresh rate (hz)';




