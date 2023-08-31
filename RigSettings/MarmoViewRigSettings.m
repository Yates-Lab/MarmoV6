
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
RigName = 'Laptop';

switch RigName

    case 'Laser'
        S.inputs = {'eyetrack_OpenIris'};%{'eyetrack_OpenIris','eyetrack_dummy'};%,'treadmill_arduino'};
        S.outputs = {'output_datapixx2','output_sbx2p'};
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
        S.screenDistance = 57;              % Distance of eye to screen (cm)
        S.pixPerDeg = PixPerDeg(S.screenDistance,S.screenWidth,S.screenRect(3));
        
        
        S.eyetrack_dummy = true;
        S.feedback_sound = [];        
        S.DummyScreen = false; % TODO: remove this parameter (it should be covered by screen Rect. Is it? NO!!!!! But it should be)
        


    
    case 'testTDM'
        S.inputs = {'eyetrack_OpenIris','treadmill_arduino'};%{'eyetrack_OpenIris','treadmill_arduino'};
        S.outputs = {'output_datapixx'};
        S.feedback = {'feedback_newera'};%'feedback_sound',

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
        S.output_datapixx.KeepUnmatched =true;
        S.DataPixx = true;

        %Photodiode patch parameters
        S.photodiode.rect =[3640 1960 3840 2160];%[0 0 100 100];%
        S.photodiode.init = 127;
        S.photodiode.flash = 0;
        S.photodiode.TF   = 1;

        %S.treadmill_arduino.type = 'arduino';
        S.treadmill_arduino.baud = 115200;
        S.treadmill_arduino.port = '/dev/ttyACM0';
        S.treadmill_arduino.scaleFactor = (94.25/5000); % circimference of wheel over ticks per rev
        S.treadmill_arduino.rewardMode = 'distProb';
        S.treadmill_arduino.rewardDist = 94.25/3; %PSC changed to 94.25 06052023
        S.treadmill_arduino.rewardProb = 1; % 1
        
        % setup screen
        S.monitor = 'ASUS-XG27UQR';         % Monitor used for display window
        S.screenNumber = 1;                % Designates the display for task stimuli
        S.frameRate = 60;                 % Frame rate of screen in Hz
        S.screenRect = [0 0 3840 2160];     %  Screen dimensions in pixels
        S.screenWidth = 59.6;                 % Width of screen (cm)
        S.centerPix =  [1920 1080];           % Pixels of center of the screen
        S.guiLocation = [3840+200 100 890 660];
        S.bgColour = 127; %127; %186;  % use 127 if gamma corrected
        S.gamma = 2.2716;
        S.screenDistance = 38;              % Distance of eye to screen (cm)
        S.pixPerDeg = PixPerDeg(S.screenDistance,S.screenWidth,S.screenRect(3));
        
        
        S.eyetrack_dummy = true;
        S.feedback_sound = [];        
        S.DummyScreen = false; % TODO: remove this parameter (it should be covered by screen Rect. Is it? NO!!!!! But it should be)
        

    case 'laptop'
        
        S.inputs = {'eyetrack_dummy'};
        S.outputs = [];
        S.feedback = {'feedback_dummy'};
        S.DataPixx = true;

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
         

    otherwise % laptop development

        S.inputs = {'eyetrack_dummy', 'treadmill_dummy'};
        S.outputs = [];%{''};
        S.feedback = {'feedback_dummy'};

        S.monitor = 'Laptop';         % Monitor used for display window
        S.screenNumber = 0;                 % Designates the display for task stimuli
        S.frameRate = 60;                  % Frame rate of screen in Hz
        S.screenRect = [0 0 960*2 540*2];     % Screen dimensions in pixels

        S.centerPix =  [480*2 270*2];           % Pixels of center of the screen
        S.guiLocation = [1000 100 890 660];
        S.bgColour = 127; % 186 if not gamma corrected
        S.DummyScreen = true; % TODO: remove this parameter (it should be covered by screen Rect. Is it?)


        S.gamma = 1;
        S.screenDistance = 57;              % Distance of eye to screen (cm)
        S.screenWidth = 30;                 % Width of screen (cm), spoof 30deg
        S.pixPerDeg = PixPerDeg(S.screenDistance,S.screenWidth,S.screenRect(3));
        S.treadmill_dummy.type = 'none';
        S.treadmill_dummy.rewardDist = 5;

        S.eyetrack_dummy = struct();

        S.feedback_dummy = [];
        S.feedback_sound = struct();
        S.output_usb2serial = [];
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
