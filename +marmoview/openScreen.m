function A=openScreen(S,A)
% OPENSCREEN Opens PTB window with parameters specified in S

% Initialize open GL settings
% Required before any stimulus uses Screen('BeginOpenGL', ...).
InitializeMatlabOpenGL;
featureLevel = 0; % use the 0-255 range in psychtoolbox (1 = 0-1)
PsychDefaultSetup(featureLevel);

% disable ptb welcome screen
Screen('Preference','VisualDebuglevel',3);

% close any open windows
Screen('CloseAll');

% setup the image processing pipeline for ptb
PsychImaging('PrepareConfiguration');

%Shouldn't need to do this, in fact this might break debug screen. Frame
%rate can be set from xorg but this is breaking current set up
hz=Screen('FrameRate', S.screenNumber);
if S.frameRate~=hz
    SetResolution(S.screenNumber,S.screenRect(3),S.screenRect(4),S.frameRate);
end
% PsychImaging('AddTask', 'General', 'FloatingPoint16Bit');
PsychImaging('AddTask','General','FloatingPoint32BitIfPossible', 'disableDithering',1);

% Empirically software-encoded cone stimuli already contain the inverse-gamma
% transform. All legacy protocols retain the existing PTB SimpleGamma path.
softwareEncoded = isfield(S,'gammaApplication') && ...
    strcmpi(char(S.gammaApplication),'software-encoded');
if ~softwareEncoded
    PsychImaging('AddTask','FinalFormatting','DisplayColorCorrection','SimpleGamma');
end

% create the ptb window...
if isfield(S,'DummyScreen') && S.DummyScreen
  [A.window, A.screenRect] = PsychImaging('OpenWindow',0,S.bgColour,S.screenRect);
else    
  [A.window, A.screenRect] = PsychImaging('OpenWindow',S.screenNumber,S.bgColour);
  
  if ~softwareEncoded
      % Add gamma correction. Cone-calibrated protocols can provide separate
      % encoding exponents for the red, green, and blue primaries.
      if isfield(S,'inverseGamma') && ~isempty(S.inverseGamma)
          encodingGamma = S.inverseGamma;
      else
          encodingGamma = 1 ./ S.gamma;
      end
      PsychColorCorrection('SetEncodingGamma',A.window,encodingGamma);
  end
end

A.gammaApplication = ternary(softwareEncoded, ...
    'software-encoded empirical device values','ptb-simple-gamma');

A.frameRate = FrameRate(A.window);

% bump ptb to maximum priority
A.priorityLevel = MaxPriority(A.window);

% set alpha blending/antialiasing etc.
Screen(A.window,'BlendFunction',GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);

% some propixx specific commands

if isfield(S, 'DataPixx') && S.DataPixx 
    if Datapixx('IsPropixx')
        Datapixx('Open');
        Datapixx('EnablePropixxRearProjection');
        Datapixx('EnablePropixxLampLed');
        Datapixx('RegWr');
    end
end

end


function value = ternary(condition,trueValue,falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end
