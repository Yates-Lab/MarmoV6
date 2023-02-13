% wrapper class for Eyelink eye tracker
% 8/23/2018 - Jude Mitchell .... very basic and similar to VPX approach

classdef eyetrack_eyelink < marmoview.eyetrack

  properties (SetAccess = public, GetAccess = public)
    EyeDump logical;
    eyeIdx = 1;   % LEFT EYE, Default
    screen = 0;
    tracker_info = [];
    eyeFile = [];
    eyePath = [];
  end
  
  methods
    function o = eyetrack_eyelink(h,winPtr,eyeFile,eyePath,varargin) % h is the handle for the marmoview gui

      % initialise input parser
      args = varargin;
      p = inputParser;
      p.addParameter('EyeDump',true,@islogical); % default 1, do EyeDump
      p.addParameter('screen',0,@isfloat); % default 1, do EyeDump
      p.parse(varargin{:});

      args = p.Results;  
      o.EyeDump = args.EyeDump;
      o.screen = args.screen;
      
      %******** save desired output file path to move edf file at end
      o.eyeFile = eyeFile;
      o.eyePath = eyePath;
      %***********************
      
      if o.screen    
           o.tracker_info = eyetrack_eyelink.Initialize_params(o.screen, winPtr, 'eyelink_use',1,'saveEDF',o.EyeDump);
           o.tracker_info = Eyelink.setup(o.tracker_info);
           if (strcmp(o.tracker_info.EYE_USED,'RIGHT'))
               o.eyeIdx = 2;
           else
               o.eyeIdx = 1;
           end
      end
      
    end

    function startfile(o,handles)
        if o.EyeDump
             eyeFile = sprintf('%s_%s_%s_%s', ...
                              handles.outputPrefix, ...
                              handles.outputSubject, ...
                              handles.outputDate, ...
                              handles.outputSuffix);
               eyePath = handles.outputPath;
           %note empty function here, startfile happens on init for Eyelink
           % so see the setup function above
        end
    end
    
    function closefile(o)
        if o.EyeDump 
           Eyelink('CloseFile'); 
           if ~isempty(o.eyeFile) && ~isempty(o.eyePath)
               file = o.tracker_info.edfFile;
               result = Eyelink('Receivefile',file,pwd,1); 
               if (result == -1)
                   warning('pds:EyelinkGetFiles', ['receiving ' file '.edf failed!'])   
               else
                   file_edf = [file,'.edf'];
                   disp(['Files received: ' file_edf]);
                   disp('   ');
                   filedest = [fullfile(o.eyePath,o.eyeFile),'.edf'];
                   [result,mess,~] = movefile(file_edf,filedest);
                   if (result == 0)
                       fprintf('Error in moving .edf file %s to %s\n',file,filedest);
                       disp(mess);
                   else
                       fprintf('Success: moved %s to %s\n',file,filedest);
                       delete(file);
                   end
               end
           end
        end
        Eyelink.finish(o.tracker_info);
    end

    function unpause(o)   
        if o.EyeDump
           Eyelink('StartRecording');   
           % vpx_SendCommandString('dataFile_Pause No');
        end
    end

    function pause(o)
        if o.EyeDump
          Eyelink('StopRecording');  
          % vpx_SendCommandString('dataFile_Pause Yes');
        end
    end

    function [x,y] = getgaze(o)
           eye_data = Eyelink('NewestFloatSample');
           if isfield(eye_data,'gx')
               x = -eye_data.px(o.eyeIdx)/32768;  
               y = eye_data.py(o.eyeIdx)/32768; 
               y = 1 - y;  % why bother retaining this from VPX?
           else
               disp(num2str(eye_data))
               x = 0;
               y = 0;
           end
    end
    
    function r = getpupil(o)
        r = 0;  % don't need it online, will see if EDF file has it
    end
    
    function sendcommand(~,tstring, varargin)
        Eyelink('message', tstring);
    end
    
    function endtrial(~)
    end
    
  end % methods

  methods (Static)

      function tracker_info = Initialize_params(whichscreen,wPtr,varargin)

          [winwidth, winheight] = WindowSize(wPtr);
          resolution = Screen('Resolution', whichscreen);

          tracker_info = struct('whichscreen', whichscreen, ...
              'pixelsPerGazeCoordinate', [resolution.width, resolution.height], ... % X, Y screen pixels per 'gaze unit'
              ... % parameters for getFixation()
              'fixationSymbol', '+', ... % 'r' for rect, 'c' for circle, 'b' for bullseye, or '+' for plus
              'fixationSymbolSize', [10, 10], ... % pixel size of fixation symbol, independent of the 'Rect' below
              'fixationSymbolColors', [255 255 255; 0 0 0], ... % primary/secondary color of fixation symbol
              'fixationTime', 1000, ... % ms. Max time allowed in getFixation()
              'fixationMinimumHold', 0.2, ... % Time required within fixation area to consider it held.
              ... % parameters for isFixation()
              'fixationCorrection', [0 0], ... % Add this to [gx, gy] to get corrected position (this is set automatically during getFixation)
              'fixationCenter', [resolution.width/2, resolution.height/2], ...
              'fixationRadius', 80, ... % true size for fixation requirement (separate from the symbol size above)
              'pre_fixationRadius', 130, ... % true size for fixation requirement for first few seconds of stimulus.
              ... % parameters for calibration
              'calibration_matrix', [], ...
              'collectQueue', true, ...
              'custom_calibration', false, ...
              'custom_calibrationScale', 0.2500, ...
              'calibration_color', [127 127 127],...
              'calibrationtargetcolor' , [255 0 0],...
              'calibrationtargetsize', 30, ...
              ... % parameters for general purpose
              'saveEDF',false,...
              'eyelink_use', true,...
              'wPtr', wPtr, ...
              'display_ppd', 1, ...
              'sound_use', 1, ...
              'winRect', [0 0 winwidth winheight], ...
              'viewdist', 57, ...  % in cm
              'widthcm', 61, ... % in cm
              'heightcm', 35);


          for val_idx=2:2:length(varargin)
              key = varargin{val_idx-1};
              if ~ischar(key)
                  warning('invalid input to initEyeTracker. After whichscreen,wPtr all arguments should be (..., ''key'', value, ...)');
              elseif ~isfield(tracker_info, key)
                  warning('unrecognized tracker_info field: ''%s''', key);
              else
                  tracker_info.(key) = varargin{val_idx};
              end
          end
      end

  end % static methods

end % classdef
