
function [S,P] = Forage12_GarboriumOverlap()

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
S.finish = 100;

% PROTOCOL PREFIX
S.protocol = 'ForageProceduralNoise';
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
S.protocolTitle = 'Foraging with back mapping';

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
P.holdDur = 0.10;
S.holdDur = 'Duration at grating for reward (s):';
P.fixRadius = 2.5;  
S.fixRadius = 'Probe reward radius(degs):';
P.trialdur = 10; 
S.trialdur = 'Trial Duration (s):';
P.iti = 0.2;
S.iti = 'Duration of intertrial interval (s):';
P.mingap = 0.2;  
S.mingap = 'Min gap to next target (s):';
P.maxgap = 0.5;
S.maxgap = 'Max gap to next target (s):';
P.probFace = 0.5;
S.probFace = 'Prob of face reward:';
P.faceradius = 1.0;  % diameter of target is dva
S.faceradius = 'Size of Face(dva):';
P.faceTime = 0.1;  % duration of flashed face, in ms
S.faceTime = 'Duration of Face Flash (s):';

%************** Probe properties
P.proberadius = 1.0;  % radius of target is dva
S.proberadius = 'Size of Target(dva):';
P.probecon = 1.0; %0.50; 
S.probecon = 'Transparency of Probe (1-none, 0-gone):';
P.proberange = 48; %a bit brighter
S.proberange = 'Luminance range of grating (1-127):';
P.stimEcc = 2.0;
S.stimEcc = 'Ecc of stimulus (degrees):';
P.stimBound = 7.0;
S.stimBound = 'Boundary if moving (degs):';
P.stimSpeed = 0;
S.stimSpeed = 'Speed of probe (degs/sec):';
P.orinum = 3;  
S.orinum = 'Orientations to sample of stimulus';
P.prefori = 40;
S.prefori = 'Preferred orientation (degs):';
P.cpd = 3;  
S.cpd = 'Probe Spatial Freq (cyc/deg)';
%*****
P.nonprefori = 130;  
S.nonprefori = 'Preferred orientation (degs):';
P.noncpd = 3;  
S.noncpd = 'Probe Spatial Freq (cyc/deg)';
%*****
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
P.noisetype = 7; %Dense Gabor
S.noisetype = 'Cannot change during protocol';

%try spfmin 1, spfrange 10, 800 gabors with noise cont at .05
P.spfmin = 2;  % will be [0.5 1 2 4 8 16]
S.spfmin = 'Minimum spat freq (cyc/deg):';

P.spfrange = 40;   % use log spacing
S.spfrange = 'Range of spat freqs (cyc/deg):';

P.noiseCenterX = 0;
S.noiseCenterX = 'Center of the noise patch (d.v.a):';

P.noiseCenterY = 0;
S.noiseCenterY = 'Center of the noise patch (d.v.a):';

P.noiseRadius = 5;
S.noiseRadius = 'width of the noise patch (d.v.a):';

P.numGabors = 8000;
S.numGabors = 'Number of Gabors:';

P.noiseFrameRate = 60;
S.noiseFrameRate = 'frame rate of the noise background:';

P.noiseContrast = 0.1;
S.noiseContrast = 'Contrast of the noise (0-1):';

P.minScale = .1;
S.minScale = 'minimum width (stdev) of gabors (d.v.a):';

P.scaleRange = .15;
S.scaleRange = 'range of stdevs (d.v.a):';
        

% P.dontsync = 1;
% S.dontsync = 'async Frame Control';
