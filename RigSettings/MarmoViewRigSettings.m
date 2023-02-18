
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

switch RigName

    case 'laptop'
        
        S.inputs = {'eyetrack_dummy'};
        S.outputs = [];
        S.feedback = {'feedback_sound'};

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
        
        S.eyetrack_dummy = [];
        S.feedback_sound = [];
  
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
%         S.EyeDump = true;        % store all eye position data
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
