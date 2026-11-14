
function S = MarmoViewRigSettings
% TODO: This should, at a minumum, have a switch, case statement for
% different rigs

% For use with MarmoView version 3   
%
% Revised by JM 8/2018 to consolidate several new features and Dummy Screen
%
% This function contains all settings for a particular rig, this way, when
% a change is made to the rig, all settings files do not need to be
% updated. This function MUST be located in a directory set in the MATLAB
% path so that it can both be called by MarmoView (in MarmoView directory)
% and by settings functions (in the MarmoView/Settings directory). I
% suggest SupportFunctions.
%
% For example, if you change the monitor set up, you only change those
% monitor related variables here.
% 


RigName = 'laptop';
HartleyStim = false; % Set true on Hartley / random-phase spiral stimulus days.

%Default setting
S.persistence=false; 
S.stereoMode=0;
S.maxTrialFrames = [];


switch RigName

   case 'Laser'
        S.persistence=false; % Flag for holding stimuli on screen between trials, 
        % set up for MT retinotopic stimuli but changes frame control so
        % may have surprising (untested) impacts on other stimuli and
        % timing of first and last frames
        S.maxTrialFrames = 115500;

        S.inputs = {'eyetrack_OpenIris'};%{'eyetrack_OpenIris','eyetrack_dummy'};%,'treadmill_arduino'};
        %S.inputs = {'eyetrack_dummy'}; % eyetrack_dummy
        S.outputs = {'output_labjackU12'};% ,'output_sbx2p'
        S.feedback = {'feedback_newera'};%,feedback_newera

        S.stereoMode=0; %Zero unless 3d screen, then 4

        %Scanbox network commands
        S.output_sbx2p.ip           = '192.168.1.2';
        S.output_sbx2p.LocalPort    = 9090;
        S.output_sbx2p.RemotePort   = 7000;

        S.eyetrack_OpenIris.ip      = '100.1.1.1';
        S.eyetrack_OpenIris.port    = 9003;
        S.eyetrack_OpenIris.UseAsEyeTracker = true;
        S.eyetracker = 'OpenIris';

        %S.feedback_newera = true;  
        S.feedback_newera.port = '/dev/ttyUSB0';              % use Newera juice pump
        S.feedback_newera.pumpDiameter = 38.1;                % internal diameter of the juice syringe (mm)
        S.feedback_newera.pumpRate = 20;                     % rate to deliver juice (ml/minute)
        S.feedback_newera.pumpDefVol = 10;                % default dispensing volume (ml)

        S.output_arduino.port = '/dev/ttyACM0';
        S.output_arduino.baud = 115200;

        S.output_labjackU12.Labjack = [];
        S.input_labjackU12.Labjack = [];

        S.arrington = false;      % use Arrington eye tracker
        S.DummyEye = false;       % use mouse instead of eye tracker
        S.solenoid = false;      % use solenoid juice delivery
        S.DummyScreen = false;   % don't use a Dummy Display
        S.EyeDump = true;        % store all eye position data
        S.output_datapixx2.KeepUnmatched =true;
        S.DataPixx = false;
        S.screenDistance = 46;%71;%46.5;%65, 66.5;%66.5;%45;63 % Distance of eye to screen (cm)

        S.monitor = 'ASUS-PG27AQN';         % Monitor used for display window
        S.screenNumber = 1;                % Designates the display for task stimuli
        S.frameRate = 240;                 % Frame rate of screen in Hz
        %S.screenRect = [0 0 1920 1080];     %  Screen dimensions in pixels
        S.screenRect = [0 0 2560 1440];     %  Screen dimensions in pixels
        S.screenWidth = 59.6;                 % Width of screen (cm)
        S.centerPix =  [S.screenRect(3)/2 S.screenRect(4)/2];           % Pixels of center of the screen
        S.guiLocation = [3840+200 100 890 660];
        S.bgColour = 127;%%127;%2^9; %127; %186;  % use 127 if gamma corrected
        S.gamma = 2.5554;
        S.pixPerDeg = PixPerDeg(S.screenDistance,S.screenWidth,S.screenRect(3));
        
         %Photodiode patch parameters
        S.photodiode.rect =[0 S.screenRect(4)-120 120 S.screenRect(4)];%[1920-100 1080-100 1920 1080];%[0 0 100 100];%
        S.photodiode.init = 0;
        S.photodiode.flash = 255;
        S.photodiode.TF   = 2;
        S.photodiode.output = 'output_labjackU12';
        S.photodiode.outputMethod = 'flipBit';
        S.photodiode.outputBit = 3; % LabJack EDigitalOut uses zero-based IO channels
        S.photodiode.flashFrames = 4;
        S.photodiode.flashStartFrame = 1;
        % setup screen
   
%         
        S.eyetrack_dummy = true;
        S.feedback_sound = [];        
        S.DummyScreen = false; % TODO: remove this parameter (it should be covered by screen Rect. Is it? NO!!!!! But it should be)
        


 case 'Laser3d'
        S.inputs = {'eyetrack_OpenIris'};%{'eyetrack_OpenIris','eyetrack_dummy'};%,'treadmill_arduino'};
        S.outputs =  {'output_datapixx2','output_sbx2p'};
        S.feedback = {'feedback_newera'};%,feedback_newera

        S.stereoMode=4;

        %Scanbox network commands
        S.output_sbx2p.ip           = '192.168.1.1';
        S.output_sbx2p.LocalPort    = 9090;
        S.output_sbx2p.RemotePort   = 7000;

        S.eyetrack_OpenIris.ip      = '100.1.1.1';
        S.eyetrack_OpenIris.port    = 9003;
        S.eyetrack_OpenIris.UseAsEyeTracker = true;
        S.eyetracker = 'OpenIris';

        %S.feedback_newera = true;  
        S.feedback_newera.port = '/dev/ttyUSB0';              % use Newera juice pump
        S.feedback_newera.pumpDiameter = 20;                % internal diameter of the juice syringe (mm)
        S.feedback_newera.pumpRate = 20;                     % rate to deliver juice (ml/minute)
        S.feedback_newera.pumpDefVol = 10;                % default dispensing volume (ml)


        S.arrington = false;      % use Arrington eye tracker
        S.DummyEye = false;       % use mouse instead of eye tracker
        S.solenoid = false;      % use solenoid juice delivery
        S.DummyScreen = false;   % don't use a Dummy Display
        S.EyeDump = true;        % store all eye position data
        S.output_datapixx2.KeepUnmatched =true;
        S.DataPixx = true;

        %Photodiode patch parameters
        S.photodiode.rect =[0 1080-100 100 1080];%[1920-100 1080-100 1920 1080];%[0 0 100 100];%
        S.photodiode.init = 0;
        S.photodiode.flash = 255;
        S.photodiode.TF   = 2;
        S.photodiode.output = 'output_datapixx2';
        S.photodiode.outputMethod = 'flipBitNoSync';
        S.photodiode.outputBit = 4;
        S.photodiode.flashFrames = 4;
        S.photodiode.flashStartFrame = 1;


        % setup screen
        S.monitor = '3D - Acer';         % Monitor used for display window
        S.screenNumber = 1;                % Designates the display for task stimuli
        S.frameRate = 60;                 % Frame rate of screen in Hz
        S.screenRect = [0 0 1920 1080];     %  Screen dimensions in pixels
        S.screenWidth = 59.6;                 % Width of screen (cm)
        S.centerPix =  [960 540];           % Pixels of center of the screen
        S.guiLocation = [800 100 890 660];
        S.bgColour = 127; 
        S.gamma = 1.30; %measured 6/29/2023 with extech easyview 33
        S.screenDistance = 65;              % Distance of eye to screen (cm)
        S.pixPerDeg = PixPerDeg(S.screenDistance,S.screenWidth,S.screenRect(3));
        
        
        S.eyetrack_dummy = true;
        S.feedback_sound = [];        
        S.DummyScreen = false; % TODO: remove this parameter (it should be covered by screen Rect. Is it? NO!!!!! But it should be)
        

 

    case {'TDM','testTDM'}
        % Standard TDM treadmill setup.
        S.persistence = false;
        S.maxTrialFrames = 12800;
        S.bgColour = 127; % use 127 if gamma corrected
        % Procedural shader for Hartley requires (for now):
        % S.bgColour = 0.5; % luminance values are normalized between 0 and 1
        % InitializeMatlabOpenGL

        S.inputs = {'eyetrack_OpenIris'};
        % S.inputs = {'eyetrack_OpenIris_pupil_right'};
        % S.inputs = {'eyetrack_dummy', 'treadmill_arduino'};
        % S.inputs = {'eyetrack_OpenIris', 'trackball_mouseDevice'};
        S.outputs = {'output_datapixx'};
        S.feedback = {'feedback_newera'};
        S.frameRate = 240;

        S.eyetrack_OpenIris.ip      = '100.1.1.1';
        S.eyetrack_OpenIris.port    = 9003;
        S.eyetrack_OpenIris.UseAsEyeTracker = true;
        S.eyetracker = 'OpenIris';

        S.eyetrack_OpenIris_pupil_right.ip      = '100.1.1.1';
        S.eyetrack_OpenIris_pupil_right.port    = 9003;
        S.eyetrack_OpenIris_pupil_right.UseAsEyeTracker = true;

        S.feedback_newera.port = '/dev/ttyUSB0';              % use Newera juice pump
        S.feedback_newera.pumpDiameter = 38.1;                % internal diameter of the juice syringe (mm)
        S.feedback_newera.pumpRate = 20;                      % rate to deliver juice (ml/minute)
        S.feedback_newera.pumpDefVol = 2;                     % default dispensing volume (ml)

        S.arrington = false;      % use Arrington eye tracker
        S.DummyEye = false;       % use mouse instead of eye tracker
        S.solenoid = false;       % use solenoid juice delivery
        S.DummyScreen = false;    % don't use a Dummy Display
        S.EyeDump = true;         % store all eye position data
        S.output_datapixx.KeepUnmatched = true;
        S.DataPixx = true;

        S.treadmill_arduino.baud = 115200;
        S.treadmill_arduino.port = '/dev/ttyACM0';
        S.treadmill_arduino.scaleFactor = (94.25/5000); % circumference of wheel over ticks per rev
        S.treadmill_arduino.rewardMode = 'distProb';
        S.treadmill_arduino.rewardDist = 94.25/5;
        S.treadmill_arduino.rewardProb = 1;

        S.trackball_mouseDevice.baud = 115200;
        S.trackball_mouseDevice.port = '/dev/ttyACM0';
        S.trackball_mouseDevice.scaleFactor = (94.25/5000); % circumference of wheel over ticks per rev
        S.trackball_mouseDevice.rewardMode = 'distProb';
        S.trackball_mouseDevice.rewardDist = 94.25/5;
        S.trackball_mouseDevice.rewardProb = 1;
        
        % setup screen
        S.monitor = 'ASUS-PG27AQN';         % Monitor used for display window
        S.screenNumber = 1;                % Designates the display for task stimuli
        S.screenRect = [0 0 2560 1440];     % Screen dimensions in pixels
        S.screenWidth = 59.6;               % Width of screen (cm)
        S.centerPix = [2560 1440]/2;        % Pixels of center of the screen
        S.guiLocation = [3840+200 100 890 660];

        % fitting with crtGamma, CalTDM0703
        % Exponent for device 1 is 2.19315
        % Exponent for device 2 is 2.22572
        % Exponent for device 3 is 2.15016
        S.gamma = mean([2.19315 2.22572 2.15016]);

        S.screenDistance = 63.5;            % Distance of eye to screen (cm)
        S.pixPerDeg = PixPerDeg(S.screenDistance,S.screenWidth,S.screenRect(3));
        
        % Photodiode patch parameters
        S.photodiode.rect = [S.screenRect(3)-150 S.screenRect(4)-150 S.screenRect(3) S.screenRect(4)];
        S.photodiode.init = 127;
        S.photodiode.flash = 0;
        S.photodiode.TF   = 1;
        S.photodiode.output = 'output_datapixx';
        S.photodiode.outputMethod = 'datapixxDoutVideoSync';
        S.photodiode.outputBit = 4;
        S.photodiode.flashFrames = 1;
        S.photodiode.flashStartFrame = 1;

        S.eyetrack_dummy = true;
        S.feedback_sound = [];        
        S.DummyScreen = false; % TODO: remove this parameter (it should be covered by screen Rect. Is it? NO!!!!! But it should be)
        

    case 'Dell test'
        
        S.inputs = {'eyetrack_dummy'};
        S.outputs = [];
        S.feedback = {'feedback_dummy'};%[];%{'feedback_dummy'};
        S.DataPixx = false;

        % Dell P2419HC software-test configuration. The cone calibration is
        % a P2419H spectral proxy with assumed gamma and is not experimental.
        S.monitor = 'DELL_P2419HC';
        S.screenNumber = max(Screen('Screens')); % Highest-index display, normally external Dell
        S.frameRate = 60;
        S.screenRect = [0 0 1920 1080];
        S.screenWidth = 52.704;              % Active display width (cm)
        S.centerPix = S.screenRect(3:4)/2;
        S.guiLocation = [1000 100 890 660];
        S.bgColour = [127.5 127.5 127.5];
        S.gamma = [2.2 2.2 2.2];
        S.inverseGamma = 1 ./ S.gamma;
        S.screenDistance = 87;               % Viewing distance (cm)
        S.pixPerDeg = PixPerDeg(S.screenDistance,S.screenWidth,S.screenRect(3));
        S.DummyScreen = false;
        S.coneCalibrationFile = fullfile( ...
            'C:\Users\Declan\Documents\2026','ConeColorMath', ...
            'Dummy_DELL_P2419HC_proxy','exports', ...
            'human_T_558_530_420','manifest.json');
        S.coneCalibrationIsDummy = true;
        S.coneCalibrationPurpose = 'SOFTWARE TESTING ONLY - NOT FOR EXPERIMENTS';
        taskRoot = fileparts(fileparts(mfilename('fullpath')));
        S.humanConeCalibrationFile = fullfile(taskRoot,'SupportData', ...
            'ConeCalibration','HumanIsoluminantML', ...
            'ConeMath2026_proxy_results.mat');
        S.allowDummyHumanConeCalibration = true;
        S.humanIsoluminanceAdjustment = 0;
        
        S.eyetrack_dummy = struct('ScreenNumber',S.screenNumber);
        S.feedback_dummy = [];
        
        
  
    case 'testIBL'

        S.inputs = {'eyetrack_dummy', 'steering_wheel_arduino'};
        S.outputs = [];
        S.feedback = {'feedback_sound','feedback_newera'};

        S.eyetrack_dummy = [];
        S.steering_wheel_arduino = [];
        S.feedback_sound = [];
        S.feedback_newera = true;
        S.steering_wheel_arduino.port = '/dev/ttyACM0';
  


%         S.newera = true;         % use Newera juice pump
%         S.eyetracker = 'none';   % modify to incorporate eye tracker 
%         S.arrington = false;      % use Arrington eye tracker
%         S.DummyEye = true;       % use mouse instead of eye tracker
%         S.solenoid = false;      % use solenoid juice delivery
%         S.DummyScreen = false;   % don't use a Dummy Display
         S.EyeDump = true;        % store all eye position data
%         S.DataPixx = false;
        
        % setup screen
        S.monitor = 'ASUS-XG27UQR';         % Monitor used for display window
        S.screenNumber = 1;                % Designates the display for task stimuli
        S.frameRate = 60;                 % Frame rate of screen in Hz *this monitor can down sample to 240Hz 
        S.screenRect = [0 0 3840 2160];     %  Screen dimensions in pixels
        S.screenWidth = 59.6;                 % Width of screen (cm)
        S.centerPix =  [1920 1080];           % Pixels of center of the screen
        S.guiLocation = [200 100 890 660];
        S.bgColour = 127; %127; %186;  % use 127 if gamma corrected
        S.gamma = 2.56;
        S.screenDistance = 56;              % Distance of eye to screen (cm)
        S.pixPerDeg = PixPerDeg(S.screenDistance,S.screenWidth,S.screenRect(3));
 
    case 'laptop'
        
        S.inputs = {'eyetrack_dummy'};
        S.outputs = [];
        S.feedback = {'feedback_dummy'};
        S.DataPixx = false; % Dummy laptop display has no DataPixx hardware.

        S.monitor = 'Laptop';         % Monitor used for display window
        S.screenNumber = 0;                 % Designates the display for task stimuli
        S.frameRate = 60;                  % Frame rate of screen in Hz
        S.screenRect = [0 0 960 540];     % Screen dimensions in pixels
        S.screenWidth = 15;                 % Width of screen (cm)
        S.centerPix =  [480 270];           % Pixels of center of the screen
        S.guiLocation = [1000 100 890 660];
        S.bgColour = 127; % 186 if not gamma corrected

        S.screenDistance = 14; %57;         % Distance of eye to screen (cm)
        S.pixPerDeg = PixPerDeg(S.screenDistance,S.screenWidth,S.screenRect(3));
        S.DummyScreen = true; % TODO: remove this parameter (it should be covered by screen Rect. Is it?)

        S.gamma = 1;
        S.screenDistance = 87;              % Distance of eye to screen (cm)
        S.pixPerDeg = PixPerDeg(S.screenDistance,S.screenWidth,S.screenRect(3));
        
        S.eyetrack_dummy = true;
        S.feedback_dummy = [];
        
        
  

    otherwise % laptop development

        S.inputs = {'eyetrack_dummy', 'treadmill_dummy'};
        S.outputs = {'output_usb2serial'};
        S.feedback = {'feedback_dummy', 'feedback_sound'};

        S.monitor = 'Laptop';         % Monitor used for display window
        S.screenNumber = 0;                 % Designates the display for task stimuli
        S.frameRate = 60;                  % Frame rate of screen in Hz
        S.screenRect = [0 0 960 540];     % Screen dimensions in pixels
        S.screenWidth = 15;                 % Width of screen (cm)
        S.centerPix =  [480 270];           % Pixels of center of the screen
        S.guiLocation = [1000 100 890 660];
        S.bgColour = 127; % 186 if not gamma corrected
        S.DummyScreen = true; % TODO: remove this parameter (it should be covered by screen Rect. Is it?)

        S.screenDistance = 14; %57;         % Distance of eye to screen (cm)
        S.pixPerDeg = PixPerDeg(S.screenDistance,S.screenWidth,S.screenRect(3));

        S.gamma = 1;
        S.screenDistance = 87;              % Distance of eye to screen (cm)
        S.pixPerDeg = PixPerDeg(S.screenDistance,S.screenWidth,S.screenRect(3));
        S.treadmill_dummy.type = 'none';
        S.treadmill_dummy.rewardDist = 5;

        S.eyetrack_dummy = struct();

        S.feedback_dummy = [];
        S.feedback_sound = struct();
        S.output_usb2serial = [];
end
        
% Apply after rig selection so each rig's ordinary background is preserved
% when the manual switch is off.
S.HartleyStim = HartleyStim;
if HartleyStim
    InitializeMatlabOpenGL;
    S.bgColour = 0.5;
end

S.TimeSensitive = [];  % default, allow GUI updating in run func states
%***************************

% S.newera.pumpCom = 'COM9';
% S.newera.pumpDiameter = 20;
% S.newera.pumpRate = 20;
% S.newera.pumpDefVol = 10;




if ~isfield(S, 'gamma')
    S.gamma = 2.2;                  % Single value gamma correction, this
end                                 % works for BenQ, others might need a
                                    % table based correction                                 
if ~isfield(S, 'eyelink') % backwards compatibility
    S.eyelink = false;
end
