
function [S,P] = ForageMT

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
S.finish = 80;

% PROTOCOL PREFIX
S.protocol = 'ForageMT';
% PROTOCOL PREFIXS
S.protocol_class = ['protocols.PR_',S.protocol];


%NOTE: in MarmoView6 subject is entered in GUI

%******** Don't allow in trial calibration for this one (comment out)
% P.InTrialCalib = 1;
% S.InTrialCalib = 'Eye Calib in Trials';
S.TimeSensitive = 1:7;

% STORE EYE POSITION DATA
% S.EyeDump = false;

% Define Banner text to identify the experimental protocol
% recommend maximum of ~28 characters
S.protocolTitle = 'Foraging with MT mapping';

%%%%% END OF NECESSARY VARIABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%% PARAMETERS -- VARIABLES FOR TASK, CAN CHANGE WHILE RUNNING %%%%%%%%%
% INCLUDES STIMULUS PARAMETERS, DURATIONS, FLAGS FOR TASK OPTIONS
% MUST BE SINGLE VALUE, NUMERIC -- NO STRINGS OR ARRAYS!
% THEY ALSO MUST INCLUDE DESCRIPTION OF THE VALUE IN THE SETTINGS ARRAY

% Reward setting
P.rewardNumber = 1;   % Max juice, only one drop ... it is so easy!
S.rewardNumber = 'Number of juice pulses to deliver:';
P.CycleBackImage = 5;
S.CycleBackImage = 'If def, backimage every # trials:';

%******* trial timing and reward
P.holdDur = 0.15;
S.holdDur = 'Duration at grating for reward (s):';
P.fixRadius = 2.5;  
S.fixRadius = 'Probe reward radius(degs):';
P.trialdur = 10; 
S.trialdur = 'Trial Duration (s):';
P.iti = 0.5;
S.iti = 'Duration of intertrial interval (s):';
P.mingap = 0.4;  
S.mingap = 'Min gap to next target (s):';
P.maxgap = 1.6;
S.maxgap = 'Max gap to next target (s):';
P.probFace = 0.5;
S.probFace = 'Prob of face reward:';
P.faceradius = 1.0;  % diameter of target is dva
S.faceradius = 'Size of Face(dva):';
P.faceTime = 0.1;  % duration of flashed face, in ms
S.faceTime = 'Duration of Face Flash (s):';

%************** Probe properties
P.proberadius = 1.5;  % radius of target is dva
S.proberadius = 'Size of Target(dva):';
P.probecon = 0.60; 
S.probecon = 'Transparency of Probe (1-none, 0-gone):';
P.proberange = 80; %
S.proberange = 'Luminance range of grating (1-127):';
P.stimEcc = 4.0;
S.stimEcc = 'Ecc of stimulus (degrees):';
P.stimBound = 7.0;
S.stimBound = 'Boundary if moving (degs):';
P.stimSpeed = 0;
S.stimSpeed = 'Speed of probe (degs/sec):';
P.orinum = 3;  
S.orinum = 'Orientations to sample of stimulus';
P.prefori = 45;  
S.prefori = 'Preferred orientation (degs):';
P.cpd = 2;  
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
P.noisetype = 5; %5;%6; %5; %2;
S.noisetype = 'Background (1-hartley, 2-spatial, 5-motion...):';

if (P.noisetype == 5)
    %****** in this version moving large dots for motion RF
    P.snoisewidth = 25.0;  % radius of noise field around origin
    S.snoisewidth = 'Spatial noise width (degs, +/- origin):';
    P.snoiseheight = 15.0;  % radius of noise field around origin
    S.snoiseheight = 'Spatial noise height (degs, +/- origin):';
    P.snoisenum = 18; %32; %sub-samples per trial, 16, 8, and 4   % number of white/black ovals to draw
    S.snoisenum = 'Number of noise ovals:';
    P.snoisediam = 1.0;  % diameter in dva of noise oval
    S.snoisediam = 'Diameter of noise ovals (dva): ';
    P.snoiselife = 12;  % lifetime in video frames - %6-120Hz, 3-60Hz, 12-240Hz - total lifetime around 50.4ms
    S.snoiselife = 'Lifetime in frames';
    P.snoisespds = 9;  % number speeds, (log spaced from base), 
                       % 2 * (sqrt(2)^(spds-1)) .... 2,2.8,4,5.6,8,11.3,16,22.6,32
    S.snoisespds = 'Number of speeds:';
    P.snoisebase = 2.0;  % motion speed
    S.snoisebase= 'Base speed of dots:';
    P.snoisedirs = 16;  % number of speed directions
    S.snoisedirs = 'Number of directions:';
    P.range = 127;
    S.range = 'Luminance range of grating (1-127):';
end

