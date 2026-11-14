
function [S,P] = OKN_converging()

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
S.protocol = 'OKN_converging';
% PROTOCOL PREFIXS
S.protocol_class = ['protocols.PR_',S.protocol];


%NOTE: in MarmoView2 subject is entered in GUI

%******** Don't allow in trial calibration for this one (comment out)
% P.InTrialCalib = 1;
% S.InTrialCalib = 'Eye Calib in Trials';
S.TimeSensitive = 1;

% STORE EYE POSITION DATA
% S.EyeDump = false;

% Define Banner text to identify the experimental protocol
% recommend maximum of ~28 characters
S.protocolTitle = 'OKN driving stimuli test for mouse and marmoset';

%%%%% END OF NECESSARY VARIABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%% PARAMETERS -- VARIABLES FOR TASK, CAN CHANGE WHILE RUNNING %%%%%%%%%
% INCLUDES STIMULUS PARAMETERS, DURATIONS, FLAGS FOR TASK OPTIONS
% MUST BE SINGLE VALUE, NUMERIC -- NO STRINGS OR ARRAYS!
% THEY ALSO MUST INCLUDE DESCRIPTION OF THE VALUE IN THE SETTINGS ARRAY

% Reward setting
P.rewardNumber = 1;   % Max juice, only one drop ... it is so easy!
S.rewardNumber = 'Number of juice pulses to deliver:';
P.CycleBackImage = 50;
S.CycleBackImage = 'If def, backimage every # trials:';

%******* trial timing and reward
P.trialdur = 10; 
S.trialdur = 'Trial Duration (s):';
P.iti = 0.5;
S.iti = 'Duration of intertrial interval (s):';

%************** Probe properties
P.proberadius = 1.0;  % radius of target is dva
S.proberadius = 'Size of Target(dva):';
P.probecon = 1.0; %0.50; 
S.probecon = 'Transparency of Probe (1-none, 0-gone):';
P.lumrange = 48; %a bit brighter
S.lumrange = 'Luminance range of grating (1-127):';
P.stimEcc = 4.0;
S.stimEcc = 'Ecc of stimulus (degrees):';
P.stimBound = 7.0;
S.stimBound = 'Boundary if moving (degs):';
P.stimSpeed = 0;
S.stimSpeed = 'Speed (degs/sec):';
P.prefori = 40;
S.prefori = 'Orientation (degs):';
P.cpd = 3;  
S.cpd = 'Spatial Freq (cyc/deg)';
%*****
P.bkgd = 127;
S.bkgd = 'Choose a grating background color (0-255):';
P.phase = 0;
S.phase = 'Grating phase (-1 to 1):';
P.squareWave = 1;
S.squareWave = '0 - sine wave, 1 - square wave';

% Gaze indicator
P.eyeRadius = 1.5; % 1.5;
S.eyeRadius = 'Gaze indicator radius (degrees):';
P.eyeIntensity = 5;
S.eyeIntensity = 'Indicator intensity:';
P.showEye = 0;
S.showEye = 'Show the gaze indicator? (0 or 1):';

%***** FORAGE CAN ACCEPT DIFFERENT BACKGROUND TYPES *****
P.stimtype = 2; % this corresponds to what PR_ForageProceduralNoise does
S.stimtype = 'Cannot change during protocol';

switch P.stimtype
    case 0 % Full screeen square wave grating
        P.numDir = 1;
        S.numDir = 'Number of directions to draw from:';

        P.GratSFmin = 0.33;  % will be [0.5 1 2 4 8]
        S.GratSFmin = 'Minimum spat freq (cyc/deg):';
        
        P.GratNumOct = 0;   % use log spacing
        S.GratNumOct = 'Num Spat Freq Octaves:';
    
        P.GratSpeed = 11;
        S.GratSpeed = 'Grating speed(s) (deg/sec):';

        P.GratCtrX = 0;
        S.GratCtX = 'Grating Position X (d.v.a. from center):';
        
        P.GratCtrY = 0;
        S.GratCtrY = 'Grating Position Y (d.v.a. from center):';
        
        P.GratDiameter = inf;
        S.GratDiameter = 'Grating Diameter (d.v.a., inf = full):';
        
        P.GratDurOn = 100;
        S.GratDurOn = 'Grating on duration (frames):';
        
        P.GratDurOff = 40;
        S.GratDurOff = 'Grating min ISI duration (frames):';
        
        P.GratISIjit = 10;
        S.GratISIjit = 'ISI jitter amount (frames, added to Off duration:';
        
        P.GratCon = 0.5;
        S.GratCon = 'Grating contrast:';
        
        P.RandPhase = true;
        S.RandPhase = 'Randomize grating phase (1 or 0):';

    case 1 % Converging optic flow

    case 2 % 1D square waves, 
        P.numDir = 1;
        S.numDir = 'Number of directions to draw from:';

        P.GratSFmin = 0.33;  % will be [0.5 1 2 4 8]
        S.GratSFmin = 'Minimum spat freq (cyc/deg):';
        
        P.GratNumOct = 0;   % use log spacing
        S.GratNumOct = 'Num Spat Freq Octaves:';
    
        P.GratSpeed = 11;
        S.GratSpeed = 'Grating speed(s) (deg/sec):';

        P.GratCtrX = 0;
        S.GratCtX = 'Grating Position X (d.v.a. from center):';
        
        P.GratCtrY = 0;
        S.GratCtrY = 'Grating Position Y (d.v.a. from center):';
        
        P.GratDiameter = inf;
        S.GratDiameter = 'Grating Diameter (d.v.a., inf = full):';
        
        P.GratDurOn = 24000;
        S.GratDurOn = 'Grating on duration (frames):';
        
        P.GratDurOff = 40;
        S.GratDurOff = 'Grating min ISI duration (frames):';
        
        P.GratISIjit = 10;
        S.GratISIjit = 'ISI jitter amount (frames, added to Off duration:';
        
        P.GratCon = 0.5;
        S.GratCon = 'Grating contrast:';
        
        P.RandPhase = true;
        S.RandPhase = 'Randomize grating phase (1 or 0):';

    case 3 % 1D square waves with perspective

    case 4 % Bullseye
                
end

% P.dontsync = 1;
% S.dontsync = 'async Frame Control';
