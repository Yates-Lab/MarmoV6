
function [S,P] = circ1Dsettings

%%%% NECESSARY VARIABLES FOR GUI
%%%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% LOAD THE RIG SETTINGS, THESE HOLD CRUCIAL VARIABLES SPECIFIC TO THE RIG,
% IF A CHANGE IS MADE TO THE RIG, CHANGE THE RIG SETTINGS FUNCTION IN
% SUPPORT FUNCTIONS
S = MarmoViewRigSettings;

% NOTE THE MARMOVIEW VERSION USED FOR THIS SETTINGS FILE, IF AN ERROR, IT
% MIGHT BE A VERSION PROBLEM
S.MarmoViewVersion = '5';

% PARAMETER DESCRIBING TRIAL NUMBER TO STOP TASK
S.finish = 200;

% PROTOCOL PREFIX
S.protocol = 'bartestStim';
% PROTOCOL PREFIXS
S.protocol_class = ['protocols.PR_',S.protocol];


%NOTE: in MarmoView2 subject is entered in GUI

%******** Don't allow in trial calibration for this one (comment out)
% P.InTrialCalib = 1;
% S.InTrialCalib = 'Eye Calib in Trials';
S.TimeSensitive = 1:7;

% STORE EYE POSITION DATA
% S.EyeDump = false;

% Define Banner text to identify the experimental protocol
% recommend maximum of ~28 characters
S.protocolTitle = 'Foraging Edit for 1d noise';

%%%%% END OF NECESSARY VARIABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%% PARAMETERS -- VARIABLES FOR TASK, CAN CHANGE WHILE RUNNING %%%%%%%%%
% INCLUDES STIMULUS PARAMETERS, DURATIONS, FLAGS FOR TASK OPTIONS
% MUST BE SINGLE VALUE, NUMERIC -- NO STRINGS OR ARRAYS!
% THEY ALSO MUST INCLUDE DESCRIPTION OF THE VALUE IN THE SETTINGS ARRAY

% Reward setting
P.rewardNumber = 1;   % Max juice, only one drop ... it is so easy!
S.rewardNumber = 'Number of juice pulses to deliver:';
P.CycleBackImage = 25;
S.CycleBackImage = 'If def, backimage every # trials:';

%******* trial timing and reward
P.holdDur = 1.0;
S.holdDur = 'Duration at grating for reward (s):';
P.Radius = 4.0;  
S.Radius = 'Probe/Face/Fix radius(degs):';

% P.faceradius = 5.0;  % diameter of target is dva
% S.faceradius = 'Size of Face(dva):';
% P.fixRadius = 5.0;  
% S.fixRadius = 'Probe reward radius(degs):';
% P.proberadius = 5;  % radius of target is dva
% S.proberadius = 'Size of Target(dva):';

P.trialdur = 10; 
S.trialdur = 'Trial Duration (s):';
P.iti = 0.1;
S.iti = 'Duration of intertrial interval (s):';
P.mingap = 0.1;  
S.mingap = 'Min gap to next target (s):';
P.maxgap = 0.4;
S.maxgap = 'Max gap to next target (s):';
P.probFace = 0.5;
S.probFace = 'Prob of face reward:';

P.faceTime = 0.1;  % duration of flashed face, in ms
S.faceTime = 'Duration of Face Flash (s):';

%************** Probe properties
P.barwidth = .25;  % radius of target is dva
S.barwidth = 'Width of bars(deg):';
P.nFramesPerStim = 10;  % radius of target is dva
S.nFramesPerStim = 'n screen frames per stimulus frame:';
P.nSecondsPreGen = 400; %40 ten second trials  
S.nSecondsPreGen = 'seconds of stim frames to prerender';

P.probecon = 1.0; 
S.probecon = 'Transparency of Probe (1-none, 0-gone):';
P.sparsity = 1; 
S.sparsity = 'Sparsity of stimuli (0-dense,1-medium, 2-sparse) stds grayed out';
P.proberange = 127; %
S.proberange = 'Luminance range of grating (1-127):';
P.stimEcc = 4.0;
S.stimEcc = 'Ecc of stimulus (degrees):';
P.stimBound = 7.0;
S.stimBound = 'Boundary if moving (degs):';
P.stimSpeed = 0;
S.stimSpeed = 'Speed of probe (degs/sec):';
P.orinum = 3;  
S.orinum = 'Orientations to sample of stimulus';
P.orilist = [0 90];  
S.orilist = 'Orientations to sample of stimulus';
P.cpd = 4;  
S.cpd = 'Probe Spatial Freq (cyc/deg)';
P.bkgd = 127;
S.bkgd = 'Choose a grating background color (0-255):';
P.phase = 0;
S.phase = 'Grating phase (-1 to 1):';
P.squareWave = 0;
S.squareWave = '0 - sine wave, 1 - square wave';

% Gaze indicator
P.eyeRadius = 1.5; % 1.5;
S.eyeRadius = 'Gaze indicator radius (degrees):';
P.eyeIntensity = 5;
S.eyeIntensity = 'Indicator intensity:';
P.showEye = 0;
S.showEye = 'Show the gaze indicator? (0 or 1):';

%***** FORAGE CAN ACCEPT DIFFERENT BACKGROUND TYPES *****
P.noisetype = 2;
S.noisetype = 'Background (0-none,1-hartley, 2-spatial, ...):';

if (P.noisetype == 2)
    %****** in this version fixation noise is spatial noise
    P.snoisewidth = 25.0;  % radius of noise field around origin
    S.snoisewidth = 'Spatial noise width (degs, +/- origin):';
    P.snoiseheight = 15.0;  % radius of noise field around origin
    S.snoiseheight = 'Spatial noise height (degs, +/- origin):';
    if (1)  % for V1
      P.snoisenum = 0;   % number of white/black ovals to draw
      S.snoisenum = 'Number of noise ovals:';
      P.snoisediam = 0.5;  % diameter in dva of noise oval
      S.snoisediam = 'Diameter of noise ovals (dva): ';
    else  % for MT
      P.snoisenum = 3;   % number of white/black ovals to draw
      S.snoisenum = 'Number of noise ovals:';
      P.snoisediam = 1.0;  % diameter in dva of noise oval
      S.snoisediam = 'Diameter of noise ovals (dva): '; 
    end
    P.range = 127;
    S.range = 'Luminance range of grating (1-127):';
end


