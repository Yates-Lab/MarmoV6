function varargout = MarmoV6(varargin)
% MarmoV6 M-file for MarmoV6.fig
%
%      THIS IS MarmoV6 VERSION 1B, THIS CORRESPONDS TO THE VERSION TEXT
%      IN THE MarmoV6.fig FILE
%
%      MarmoV6, by itself, creates a new MarmoV6 or raises the existing
%      singleton*.
%
%      H = MarmoV6 returns the handle to a new MarmoV6 or the handle to
%      the existing singleton*.
%
%      MarmoV6('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MarmoV6.M with the given input arguments.
%
%      MarmoV6('Property','Value',...) creates a new MarmoV6 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MarmoV6_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MarmoV6_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.    Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help MarmoV6

% Last Modified by GUIDE v2.5 23-Sep-2019 17:01:59

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MarmoV6_OpeningFcn, ...
                   'gui_OutputFcn',  @MarmoV6_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before MarmoV6 is made visible.
function MarmoV6_OpeningFcn(hObject, eventdata, handles, varargin)
    % This function has no output args, see OutputFcn.
    % hObject    handle to figure
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    % varargin   command line arguments to MarmoV6 (see VARARGIN)

    % Choose default command line output for MarmoV6
    handles.output = hObject;

    %%%%% IMPORTANT GROUNDWORK FOR THE GUI IS PLACED HERE %%%%%%%%%%%%%%%%%%%%%

    % GET SOME CRUCIAL DIRECTORIES -- THESE DIRECTORIES MUST EXIST!!
    % Present working directory, location of all GUIs
    handles.taskPath = fileparts(mfilename('fullpath'));
    % Settings directory, settings files should be kept here
    handles.settingsPath = fullfile(handles.taskPath, 'Settings');
    % Output directory, all data will be saved here!
    handles.outputPath = fullfile(handles.taskPath, 'Output');
    % Support data directory, data to support MarmoV6 or its protocols can be
    % kept here unintrusively (e.g. eye calibration values or marmoset images)
    handles.supportPath = fullfile(handles.taskPath, 'SupportData');
    %****** start with no settings file
    handles.settingsFile = 'none';
    set(handles.SettingsFile,'String',handles.settingsFile);


    % TODO: should be eyetracker and subject dependent, so we need to first
    % load up rig settings and subject name
%     handles.calibFile = 'MarmoViewLastCalib.mat';
%     set(handles.CalibFilename,'String',handles.calibFile);
% 
%     if exist(handles.calibFile, 'file')
%         tmp = load([handles.supportPath filesep handles.calibFile]);
%         handles.C.dx = tmp.dx;
%         handles.C.dy = tmp.dy;
%         handles.C.c = tmp.c;
%     else
%         handles.C.dx = .1;
%         handles.C.dy = .1;
%         handles.C.c = [0 0];
%     end

    handles.eyeTraceRadius = 15;
    % This C structure is never changed until a protocol is cleared or
    % MarmoV6 is exited, until then, it may be reset to the C values using
    % the ResetCalib callback.

    % CREATE THE STRUCTURES USED BY ALL PROTOCOLS
    handles.A = struct; % Values necessary for protocols to run current trial
    handles.S = struct; % Settings for the protocol, NOT changed while running
    handles.P = struct; % Parameters for the current protocol, changeable


    % TODO: do we want to handle the images this way??
    handles.SI = handles.S;
    handles.PI = struct;

    %****** AT SOME POINT THIS TASK CONTROL MAY INCLUDE EPHYS TIMING WRAPPER
    handles.FC = marmoview.FrameControl();   % create generic task control 

    % LOAD RIG SETTINGS TO S, THIS IS RELOADED FOR EACH PROTOCOL, SO IT SHOULD
    % BE LOCATED IN A DIRECTORY IN MATLAB'S PATH, I SUGGEST THE
    % 'MarmoV6\SupportFunctions' DIRECTORY
    handles.outputSubject = 'none';
    S = MarmoViewRigSettings;
    S.subject = handles.outputSubject;
    handles.S = S;



    % Add in the plot handles to A in case handles isn't available
    % e.g. while running protocols)
    handles.A.EyeTrace = handles.EyeTrace;
    handles.A.DataPlot1 = handles.DataPlot1;
    handles.A.DataPlot2 = handles.DataPlot2;
    handles.A.DataPlot3 = handles.DataPlot3;
    handles.A.DataPlot4 = handles.DataPlot4;
    handles.A.outputFile = 'none';


    % -------------------------------------------------------------------------
    % --- Inputs (e.g., eyetracking, treadmill, mouse, etc.)
    numInputs = numel(S.inputs);
    handles.inputs = cell(numInputs,1);

    eyechecker=0;
    for i = 1:numInputs
        assert(ismember(handles.S.inputs{i}, fieldnames(handles.S)), 'MarmoV6.m line 139: requested input needs field of that name')
        handles.inputs{i} = marmoview.(handles.S.inputs{i})(handles.S.(handles.S.inputs{i}));

        %cellfun
        if handles.inputs{i}.UseAsEyeTracker
            %Set up handles.eyetrack for direct calls later
            handles.eyetrack=handles.inputs{i};
            eyechecker=eyechecker+1;
            
            %find most recent calibration with that eyetracker, subject
            %Calibdir=dir(fullfile(handles.supportPath, handles.eyetrack, handles.outputSubject))
            % Buuuut outputSubject has not been loaded yet so take most
            % subfolders for each tracker?
            %Calibdir = dir(fullfile(handles.supportPath,(handles.S.inputs{i}), '*Calib.mat'));
            % Or just prepend filename with tracker?
            Calibdir = dir(fullfile(handles.supportPath,[(handles.S.inputs{i}) '.mat']));
            
            if ~isempty(Calibdir)
                handles.calibFile= Calibdir.name(min(Calibdir.datenum));
                tmp = load(fullfile(Calibdir,handles.calibFile));
%                 exist(handles.calibFile, 'file')
%                 tmp = load([handles.supportPath filesep handles.calibFile]);
                handles.C.dx = tmp.dx;
                handles.C.dy = tmp.dy;
                handles.C.c = tmp.c;
            else
                handles.C=handles.eyetrack.calibinit(handles.S);
%                     handles.C.dx = .1;
%                     handles.C.dy = .1;
%                     handles.C.c = [0 0];
            end
        end
    end
    assert(eyechecker==1,'MarmoV6 ln 776: one and only one input can be the active eyetracker method')

    % Load calibration variables into the A structure to be changed if needed
    handles.A = handles.C;



    % -------------------------------------------------------------------------
    % --- Outputs (e.g., datapixx, synchronization routines, etc.)
    numOutputs = numel(S.outputs);
    handles.outputs = cell(numOutputs,1);
    for i = 1:numOutputs
        assert(ismember(handles.S.outputs{i}, fieldnames(handles.S)), 'MarmoV6.m line 148: requested outputs needs parameter struct field of that name')
        handles.outputs{i} = marmoview.(handles.S.outputs{i})(handles.S.(handles.S.outputs{i}));
    end

    %Set up a generic eyetrack class to be filled with an input and a
    %generic reward class to be filled with an output
    %handles.eyetrack = marmoview.eyetrack();
    handles.reward = marmoview.feedback_dummy(handles);
    % TODO: Figure out best way to do this

    handles.A.juiceVolume = handles.reward.volume;
    handles.A.juiceUnits = handles.reward.units;
%     if isprop(handles.reward, 'volume')
%         handles.A.juiceVolume = handles.reward.volume;
%     else
%         handles.A.juiceVolume = 0;
%     end

    handles.A.juiceCounter = 0; % Initialize, juice counter is reset when loading a protocol

    %********************************************************

    %********* add the task controller for storing eye movements, flipping
    %********* frames
    % WRITE THE CALIBRATION DATA INTO THE EYE TRACKER PANEL AND GET THE SIZES 
    % OF GAIN AND SHIFT CONTROLS FOR CALIBRATING EYE POSITION
    % FOR UPDATE EYE TEXT TO RUN PROPPERLY, CALBIRATION MUST ALREADY BE IN
    % STRUCTURE 'A'
    UpdateEyeText(handles);
    handles.shiftSize = str2double(get(handles.ShiftSize,'String'));
    handles.gainSize = str2double(get(handles.GainSize,'String'));

    % THESE VARIABLES CONTROL THE RUN LOOP
    handles.runTask = false;
    handles.stopTask = false;
    %******** New parameters for running background image
    handles.runOneTrial = false;
    handles.runImage = false;
    handles.lastRunWasImage = false;

    % SET ACCESS TO GUI CONTROLS
    handles.Initialize.Enable = 'Off';
    handles.ClearSettings.Enable = 'Off';
    handles.RunTrial.Enable = 'Off';
    handles.PauseTrial.Enable = 'Off';
    handles.FlipFrame.Enable = 'Off';
    handles.Background_Image.Enable = 'Off';
    handles.Calib_Screen.Enable = 'Off';
    handles.ParameterPanel.Visible = 'Off';
    handles.EyeTrackerPanel.Visible = 'Off';
    handles.TaskPerformancePanel.Visible = 'Off';
    handles.SettingsPanel.Visible = 'Off';

    % Force to select subject name first thing
    handles.OutputPrefixEdit.Enable = 'Off';
    handles.OutputSubjectEdit.String = 'none';
    handles.outputSubject = 'none';

    handles.OutputDateEdit.Enable = 'Off';
    handles.OutputSuffixEdit.Enable = 'Off';
    %****** set names to empty for starting
    handles.outputPrefix = [];
    handles.outputDateEdit = [];
    handles.outputSuffixEdit = [];
    %**************
    tstring = 'Please select SUBJECT to begin';
    handles.StatusText.String = tstring;

    % For the protocol title, note that no protocol has been loaded yet
    handles.ProtocolTitle.String = 'No protocol is loaded.';
    % The task light is a neutral gray when no protocol is loaded
    ChangeLight(handles.TaskLight,[.5 .5 .5]);
    UpdateEyeText(handles);

    % Update handles structure
    guidata(hObject, handles);

% --- Outputs from this function are returned to the command line.
function varargout = MarmoV6_OutputFcn(hObject, eventdata, handles)  %#ok<*INUSL>
    % varargout  cell array for returning output args (see VARARGOUT);
    % hObject    handle to figure
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    
    % Get default command line output from handles structure
    varargout{1} = handles.output;


%%%%% SETTINGS PANEL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CHOOSE A SETTINGS FILE
function ChooseSettings_Callback(hObject, eventdata, handles) %#ok<*DEFNU>
    % Go into the settings path
    % TODO: DON'T DO THIS!
    cd(handles.settingsPath);
    % Have user select the file
    handles.settingsFile = uigetfile;
    % Show the selected outputfile
    if handles.settingsFile ~= 0
        set(handles.SettingsFile,'String',handles.settingsFile);
    else
    % Or no outputfile if cancelled selection
        set(handles.SettingsFile,'String','none');
        handles.settingsFile = 'none';
    end
    % If file exists, then we can get the protocol initialized
    if exist(handles.settingsFile,'file')
        if (strcmp(handles.outputSubject,'none'))
           set(handles.Initialize,'Enable','off');
           tstring = 'Please select SUBJECT NAME >>>';
        else
           set(handles.Initialize,'Enable','on');
           tstring = 'Ready to initialize protocol...';
        end
    else
        set(handles.Initialize,'Enable','off');
        tstring = 'Please select a settings file...';
    end
    % Regardless, update status
    set(handles.StatusText,'String',tstring);
    % Return to task directory
    cd(handles.taskPath);
    
    % Update handles structure
    guidata(hObject, handles);


% INITIALIZE A PROTOCOL FROM THE SETTINGS SELECTED
function Initialize_Callback(hObject, eventdata, handles)
    % PREPARE THE GUI FOR INITIALIZING THE PROTOCOL
    % Update GUI status
    set(handles.StatusText,'String','Initializing...');
    % The task light is blue only during protocol initialization
    ChangeLight(handles.TaskLight,[.2 .2 1]);
    
    % TURN OFF BUTTONS TO PREVENT FIDDLING DURING INITIALIZATION
    set(handles.ChooseSettings,'Enable','Off');
    set(handles.Initialize,'Enable','Off');
    set(handles.OutputSubjectEdit,'Enable','Off'); % subject already set
    % Effect these changes on the GUI immediately
    guidata(hObject, handles); drawnow;
    
    % GET PROTOCOL SETTINGS
    % TODO: DON'T Do This
    cd(handles.settingsPath);
    cmd = sprintf('[handles.S,handles.P] = %s;',handles.settingsFile(1:end-2));
    eval(cmd);
    handles.S.subject = handles.outputSubject;
    cd(handles.taskPath);
    
    % add the treadmill parameters
    % TODO: Specific treadmill 
    if isfield(handles.S, 'treadmill')
        fields = {'scaleFactor', 'rewardMode', 'rewardDist', 'rewardProb'};
        for f = 1:numel(fields)
            if isfield(handles.S.treadmill, fields{f})
                handles.treadmill.(fields{f}) = handles.S.treadmill.(fields{f});
                pName = ['tread' fields{f}];
                handles.P.(pName) = handles.S.treadmill.(fields{f});
                handles.S.(pName) = sprintf('Treadmill parameter %s', fields{f});
            end
        end
    end
    
    % MOVE THE GUI OFF OF THE VISUAL STIMULUS SCREEN TO THE CONSOLE SCREEN
    % THIS IS CHANGED IN PROTOCOL SETTINGS AND IS NOT A NECESSARY SETTING
    if isfield(handles.S,'guiLocation')
        set(handles.figure1,'Position',handles.S.guiLocation);
    end
    
    % SHOW THE PROTOCOL TITLE
    set(handles.ProtocolTitle,'String',handles.S.protocolTitle);
    
    % OPEN THE PTB SCREEN
    handles.A = marmoview.openScreen(handles.S,handles.A);

    % INITIALIZE THE PROTOCOL
    % TODO: Dynamic calls
%     protocols.(handles.S.protocol_class)
    cmd = sprintf('handles.PR = %s(handles.A.window);',handles.S.protocol_class);
    eval(cmd);   %Establishes the PR object
    
    %***************
    % GENERATE DEFAULT TRIALS LIST
    handles.PR.generate_trialsList(handles.S,handles.P);
    %*****************
    handles.PR.initFunc(handles.S, handles.P);
    %***************

    % ALSO GENERATE A BACKGROUND IMAGE VIEWER PROTOCOL
    %********* Setup Image Viewer Protocol ******************
    % TODO: Don't change directories
    cd(handles.settingsPath);
    [handles.SI,handles.PI] = BackImage;
    cd(handles.taskPath);
    % INITIALIZE THE Back Image Protocol 
    handles.PRI = protocols.PR_BackImage(handles.A.window);
    handles.PRI.generate_trialsList(handles.SI,handles.PI);
    handles.PRI.initFunc(handles.SI, handles.PI);
    %***************

    %*****************************************
    
    % INITIALIZE THE TASK CONTROLLER FOR THE TRIAL
    handles.FC.initialize(handles.A.window, handles.P, handles.C, handles.S);
    
    % SET UP THE OUTPUT PANEL
    % Get the output file name components
    handles.outputPrefix = handles.S.protocol;
    set(handles.OutputPrefixEdit,'String',handles.outputPrefix);
    set(handles.OutputSubjectEdit,'String',handles.outputSubject);
    handles.outputDate = char(datetime('today', 'format', 'ddMMyy'));
    set(handles.OutputDateEdit,'String',handles.outputDate);
    i = 0; handles.outputSuffix = '00';
    % Generate the file name
    handles.A.outputFile = strcat(handles.outputPrefix,'_',handles.outputSubject,...
        '_',handles.outputDate,'_',handles.outputSuffix,'.mat');
    % If the file name already exists, iterate the suffix to a nonexistant file
    while exist([handles.outputPath handles.A.outputFile],'file')
        i = i+1; handles.outputSuffix = num2str(i,'%.2d');
        handles.A.outputFile = strcat(handles.outputPrefix,'_',handles.outputSubject,...
            '_',handles.outputDate,'_',handles.outputSuffix,'.mat');
    end


    % --- initialize inputs
    % This should start recording on the eye trackers / make sure
    % synchronization is ready
    for i = 1:numel(handles.inputs)
        handles.inputs{i}.init(handles);
    end

    % initialize outputs
    for i = 1:numel(handles.outputs)
        handles.outputs{i}.init(handles);
    end


    % Show the file name on the GUI
    handles.OutputSuffixEdit.String = handles.outputSuffix;
    handles.OutputFile.String = handles.A.outputFile;

    % Note that a new output file is being used
    handles.A.newOutput = 1;

    % SET UP THE PARAMETERS PANEL
    % Trial counting section of the parameters
    handles.A.j = 1; handles.A.finish = handles.S.finish;
    handles.TrialCountText.String = ['Trial ' num2str(handles.A.j-1)];
    handles.TrialMaxText.String = num2str(handles.A.finish);
    handles.TrialMaxEdit.String = '';

    % Get strings for the parameters list
    handles.pNames = fieldnames(handles.P);         % pNames are the actual parameter names
    handles.pList = cell(size(handles.pNames,1),1); % pList is the list of parameter names with values
    for i = 1:size(handles.pNames,1)
        pName = handles.pNames{i};
        tName = sprintf('%s = %2g',pName,handles.P.(pName));
        handles.pList{i,1} = tName;
    end

    % add parameters to GUI
    handles.Parameters.String = handles.pList;
    % For the highlighted parameter, provide a description and editable value
    handles.Parameters.Value = 1;
    handles.ParameterText.String = handles.S.(handles.pNames{1});
    handles.ParameterEdit.String = num2str(handles.P.(handles.pNames{1}));

    % UPDATE ACCESS TO CONTROLS
    handles.RunTrial.Enable = 'On';
    handles.FlipFrame.Enable = 'On';
    handles.ClearSettings.Enable ='On';
    handles.ParameterPanel.Visible ='On';
    handles.EyeTrackerPanel.Visible = 'On';
    handles.OutputPanel.Visible = 'On';
    handles.OutputSubjectEdit.Enable = 'Off';
    handles.OutputPrefixEdit.Enable = 'Off';
    handles.OutputDateEdit.Enable = 'Off';
    handles.OutputSuffixEdit.Enable = 'Off';
    handles.TaskPerformancePanel.Visible = 'On';
    handles.Background_Image.Enable = 'On';
    handles.Calib_Screen.Enable = 'On';

    %******* allow for graph zoom in and out
    handles.GraphZoomIn.Enable = 'On';
    handles.GraphZoomOut.Enable = 'On';

    %*******Blank the eyetrace plot
    h = handles.EyeTrace;
    eyeRad = handles.eyeTraceRadius;
    set(h,'NextPlot','Replace');
    plot(h,0,0,'+k','LineWidth',2);
    set(h,'NextPlot','Add');
    plot(h,[-eyeRad eyeRad],[0 0],'--','Color',[.5 .5 .5]);
    plot(h,[0 0],[-eyeRad eyeRad],'--','Color',[.5 .5 .5]);
    axis(h,[-eyeRad eyeRad -eyeRad eyeRad]);
    %*************************
    
    
    % TODO: how do we handle dummy eye?
    % if handles.S.DummyEye
    %     EnableEyeCalibration(handles,'Off');  %dont update if Dummy, use mouse
    %     %******* but allow for graph zoom in and out
    %     set(handles.GraphZoomIn,'Enable','On');
    %     set(handles.GraphZoomOut,'Enable','On');
    % end

    % UPDATE GUI STATUS
    set(handles.StatusText,'String','Protocol is ready to run trials.');
    % Now that a protocol is loaded (but not running), task light is red
    ChangeLight(handles.TaskLight,[1 0 0]);

    % FINALLY, RESET THE JUICE COUNTER WHENEVER A NEW PROTOCOL IS LOADED
    handles.A.juiceCounter = 0;

    % UPDATE HANDLES STRUCTURE
    guidata(hObject,handles);


% UNLOAD CURRENT PROTOCOL, RESET GUI TO INITIAL STATE
function ClearSettings_Callback(hObject, eventdata, handles)

    % DISABLE RUNNING THINGS WHILE CLEARING
    handles.RunTrial.Enable = 'Off';
    handles.FlipFrame.Enable = 'Off';
    handles.ClearSettings.Enable = 'Off';
    handles.ChooseSettings.Enable = 'On';
    handles.Initialize.Enable = 'On';
    handles.OutputPanel.Visible = 'Off';
    handles.ParameterPanel.Visible = 'Off';
    handles.EyeTrackerPanel.Visible = 'Off';
    handles.OutputPanel.Visible = 'Off';
    handles.TaskPerformancePanel.Visible = 'Off';
    handles.Background_Image.Enable = 'Off';
    handles.Calib_Screen.Enable = 'Off';
    
    % Clear plots
    plot(handles.DataPlot1,0,0,'+k');
    plot(handles.DataPlot2,0,0,'+k');
    plot(handles.DataPlot3,0,0,'+k');
    plot(handles.DataPlot4,0,0,'+k');
    
    % Eye trace needs to be treated differently to maintain important
    % properties
    plot(handles.EyeTrace,0,0,'+k');
    handles.EyeTrace.UserData = 15; % 15 degrees of visual arc is default
    

    %INPUT/OUTPUT closefiles
    for i=1:length(handles.inputs)
        handles.inputs{i}.closefile();
    end

    for i=1:length(handles.outputs)
        handles.outputs{i}.closefile();
    end

    %****** ADDED VIA SHAUN **********
    %%% SC: eye posn data
    % tell ViewPoint to close the eye posn data file
    % TODO: fix eye tracker specific
%     handles.eyetrack.closefile();
    %*************************
    
    % DE-INITIALIZE PROTOCOL (remove screens or objects created on init)
    handles.PR.closeFunc();  % de-initialize any objects 
    handles.PRI.closeFunc(); % close the back-ground image protocol
    handles.lastRunWasImage = false;
   

    % REFORMAT DATA FILES TO CONDENSED STRUCT
    CondenseAppendedData(hObject, handles)
    
    % Close all screens from ptb
    sca;
    
    % Save the eye calibration values at closing time to the MarmoViewLastCalib
    c = handles.A.c;
    dx = handles.A.dx;
    dy = handles.A.dy;

    % TODO: how do we want to handle calibration?
%     if ~handles.S.DummyEye 
%         save([handles.supportPath 'MarmoViewLastCalib.mat'],'c','dx','dy');
%     end
    % Create a structure for A that maintains only basic values required
    % outside the protocol
    handles.C.c = c; handles.C.dx = dx; handles.C.dy = dy;
    A = handles.C;
    A.EyeTrace = handles.EyeTrace;
    A.DataPlot1 = handles.DataPlot1;
    A.DataPlot2 = handles.DataPlot2;
    A.DataPlot3 = handles.DataPlot3;
    A.DataPlot4 = handles.DataPlot4;
    A.outputFile = 'none';
    
    % Reset structures
    handles.A = A;
    handles.S = MarmoViewRigSettings;
    handles.S.subject = handles.outputSubject;
    handles.P = struct;
    handles.SI = handles.S;
    handles.PI = struct;

    % If juice delivery volume was changed during the previous protocol,
    % return it to default. Also add the juice counter for the juice button.
    % fprintf(handles.A.pump,['0 VOL ' num2str(handles.S.pumpDefVol)]);
    % handles.reward.volume = handles.S.pumpDefVol; % milliliters
    handles.A.juiceVolume = handles.reward.volume;
    handles.A.juiceCounter = 0;
    %TODO set units 
    %if handles.S.solenoid
    %    set(handles.JuiceVolumeText,'String',sprintf('%3i ms',handles.A.juiceVolume));
    %else
        set(handles.JuiceVolumeText,'String',sprintf('%3i ul',handles.A.juiceVolume));
    %end
    
    

    % RE-ENABLE CONTROLS
    handles.ChooseSettings.Enable = 'On';
    % Initialize is only available if the settings file exists
    handles.settingsFile = get(handles.SettingsFile,'String');
    if ~exist([handles.settingsPath handles.settingsFile],'file')
        handles.Initialize.Enable = 'off';
        tstring = 'Please select a settings file...';
    else
        handles.Initialize.Enable = 'on';
        tstring = 'Ready to initialize protocol...';
    end
    % Update GUI status
    handles.StatusText.String = tstring;
    % For the protocol title, note that no protocol is now loaded
    handles.ProtocolTitle.String = 'No protocol is loaded.';
    % The task light is a neutral gray when no protocol is loaded
    ChangeLight(handles.TaskLight,[.5 .5 .5]);
    
    %****** RE-ENABLE THE SUBJECT ENTRY, in case want to change subject and
    %****** continue the program without closing MarmoV6 (should be rare)
    handles.OutputPanel.Visible = 'On';
    handles.OutputPrefixEdit.Enable = 'Off';
    handles.OutputSubjectEdit.Enable = 'On';   %user can edit this!
    handles.OutputDateEdit.Enable = 'Off';
    handles.OutputSuffixEdit.Enable = 'Off';
    
    % Update handles structure
    guidata(hObject, handles);



%%%%% TRIAL CONTROL PANEL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function RunTrial_Callback(hObject, eventdata, handles)
    % SET THE TASK TO RUN
    handles.runTask = true;

    %********* store what is the current EyeTrace to plot, based on 
    %********* what protocol is most recently called (image or other)
    if ~handles.runImage
        handles.lastRunWasImage = false;
    else
        handles.lastRunWasImage = true;
    end
    %****************************

    % SET TASK LIGHT TO GREEN
    ChangeLight(handles.TaskLight,[0 1 0]);
    %*********
    
    %****** NOTE, maybe you can turn off some graphics figure features
    %******  like resize and move functions in the future
    
    %****** Gray out controls so it is clear you can't press them
    handles.RunTrial.Enable = 'Off';
    handles.FlipFrame.Enable ='Off';
    handles.Background_Image.Enable = 'Off';
    handles.Calib_Screen.Enable = 'Off';
    handles.CloseGui.Enable = 'Off';
    handles.ClearSettings.Enable = 'Off';
    handles.ChooseSettings.Enable = 'Off';
    handles.Initialize.Enable = 'Off';
    handles.OutputPrefixEdit.Enable = 'Off';
    % handles.OutputSubjectEdit.Enable = 'Off';
    handles.OutputDateEdit.Enable = 'Off';
    handles.OutputSuffixEdit.Enable = 'Off';
    %********** even more turned off
    handles.Parameters.Enable = 'Off';
    handles.TrialMaxEdit.Enable = 'Off';
    handles.JuiceVolumeEdit.Enable = 'Off';
    handles.ChooseSettings.Enable = 'Off';
    handles.Initialize.Enable = 'Off';
    handles.ParameterEdit.Enable = 'Off';
    %********* Optional Turn Offs *****************
    %****** These might remain on for calib eye
%     if ( isfield(handles.P,'InTrialCalib') && (handles.P.InTrialCalib == 1) && ...
%             (~handles.S.DummyEye) )  %dont allow calibration if dummy screen (use mouse)
%       if ~handles.S.DummyEye
%          EnableEyeCalibration(handles,'On');
%       else
%          EnableEyeCalibration(handles,'Off');
%          handles.GraphZoomIn.Enable = 'On';
%          handles.GraphZoomOut.Enable = 'On';
%       end
%       UpdateEyeText(handles);
%     else
%       EnableEyeCalibration(handles,'Off');
%       UpdateEyeText(handles);
%     end
    if isfield(handles.P,'InTrialCalib') && (handles.P.InTrialCalib == 1) 
        %dont allow calibration if dummy screen (use mouse)
%       if ~handles.S.DummyEye
%          EnableEyeCalibration(handles,'On');
%       else
        EnableEyeCalibration(handles,'Off');
        handles.GraphZoomIn.Enable = 'On';
        handles.GraphZoomOut.Enable = 'On';
        UpdateEyeText(handles);
    else
      EnableEyeCalibration(handles,'Off');
      UpdateEyeText(handles);
    end

    %********** leave the pause button functioning **
    handles.PauseTrial.Enable = 'On';
    %***********************************************

    % TODO: do we want to log data when MarmoV6 is paused
    % unpause the inputs
    for i = 1:numel(handles.inputs)
        handles.inputs{i}.unpause(handles.inputs{i});
    end
    
    %********************************

    % UPDATE GUI STATUS
    set(handles.StatusText,'String','Protocol trials are running.');

    % RESET THE JUICER COUNTER BEFORE ENTERING THE RUN LOOP
    handles.A.juiceCounter = 0;
    % UPDATE THE HANDLES 
    guidata(hObject,handles); drawnow;

    % MOVE TASK RELATED STRUCTURES OUT OF HANDLES FOR THE RUN LOOP -- this way
    % if a callback interrupts the run task function, we can update any changes
    % the interrupting callback makes to handles without affecting those task
    % related structures. E.g. we can run the task using parameters as they 
    % were at the start of the trial, while getting ready to cue any changes 
    % the user made on the next trial.
    A = handles.A;   % these structs are small enough we will pass them
    if ~handles.runImage
        S = handles.S;   % as arguments .... don't make them huge ... larger
        P = handles.P;   % data should stay in D, or inside the PR or FC objects
    else
        S = handles.SI;  % pull other arguments for image protocol
        P = handles.PI;
    end
    % IF NOT DATA FILE OPENED, CREATE AND INSERT S Struct first
    %****** ONCE OPENED, YOU ONLY APPEND TO THAT FILE EACH TRIAL NEW DATA    
    if ~exist(A.outputFile)
        save(fullfile(handles.outputPath, A.outputFile),'S');     % save settings struct to output file
    end

    %****** pass in any updated calibration params (can calib when paused!)
    handles.FC.update_eye_calib(A.c,A.dx,A.dy);
    %****** also, check if user turned on showEye during a pause
    handles.FC.update_args_from_Pstruct(P);  %showEye, eyeIntensity, eye Radius, ...
    %*********************************

    % RUN TRIALS
    CorCount = 0;   % count consecutive correct trials (for BackImage interleaving)
    SetRunBack = 0; % flag for swapping to interleaved image trials and back
    %******* 

    while handles.runTask && A.j <= A.finish   
        % 'pause', 'drawnow', 'figure', 'getframe', or 'waitfor' will allow
        % other callbacks to interrupt this run task callback -- be aware that
        % if handles aren't properly managed then changes either in the run
        % loop or in other parts of the GUI may be out-of-sync. Nothing changes
        % to GUI-wide handles until the local callback puts them there. If
        % other callbacks change handles, and they are not brought into this
        % callback, then those changes are lost when this run loop updates that
        % handles. This concept is explained further right below during the 
        % nextCmd handles management.
        
        %******* Check if automatic interleaving of BackImage trials
        %******* and set the trial accordingly
        if isfield(handles.P,'CycleBackImage')
            if handles.P.CycleBackImage > 0 
                if ~mod((CorCount+1),handles.P.CycleBackImage)
                    handles.runImage = true;
                    SetRunBack = 1;
                    S = handles.SI;
                    P = handles.PI;
                end
            end
        end
        
        %*****************************
        P.rng_before_trial = rng(); % save current state of the random number generator
        
        % set which protocol to use
        if handles.runImage
            PR = handles.PRI;
        else
            PR = handles.PR;
        end
    
    %     if isa(PR, 'protocols.protocol')
    %         PR = copy(PR); % unlink PR from handles.PR
    %     end

        % EXECUTE THE NEXT TRIAL COMMAND
        P = PR.next_trial(S,P);
        
        % UPDATE IN CASE JUICE VOLUME WAS CHANGED USING A PARAMETER
        % TODO: this should be done with feedback objects (reward is deprecated)
        % TODO: we HAVE to handle units within the objects
        if handles.A.juiceVolume ~= A.juiceVolume
            handles.reward.volume = A.juiceVolume; % A.juiceVolume is in milliliters
            if (handles.S.solenoid)
                handles.JuiceVolumeText.String = sprintf('%3i ms',A.juiceVolume*1e3);     
            else
                handles.JuiceVolumeText.String = sprintf('%3i ul',A.juiceVolume*1e3);
            end
            handles.A.juiceVolume = A.juiceVolume;
        end

        % UPDATE HANDLES FROM ANY CHANGES DURING NEXT TRIAL -- IF THIS ISN'T
        % DONE, THEN THE OTHER CALLBACKS WILL BE USING A DIFFERENT HANDLES
        % STRUCTURE THAN THIS LOOP IS
        guidata(hObject,handles);
        % ALLOW OTHER CALLBACKS INTO THE QUEUE AND UPDATE HANDLES -- 
        % HERE, HAVING UPDATED ANY RUN LOOP CHANGES TO HANDLES, WE LET OTHER
        % CALLBACKS DO THEIR THING. WE THEN GRAB THOSE HANDLES SO THE RUN LOOP
        % IS ON THE SAME PAGE. FORTUNATELY, IF A PARAMETER CHANGES IN HANDLES,
        % THAT WON'T AFFECT THE CURRENT TRIAL WHICH IS USING 'P', NOT handles.P
        pause(.001); handles = guidata(hObject);
        
        %******** IMPLEMENT DEFAULT RUN TRIAL HERE DIRECTLY **********
        %***** Note, PR will refer to the PROTOCOL object ************
        [FP,TS] = PR.prep_run_trial();

        handles.FC.set_task(FP,TS);  % load values into class for plotting (FP)
                                    % and to label TimeSensitive states (TS)

        %Eyetracking input object should
        %already be set up
        [ex,ey] = handles.eyetrack.getgaze();
        pupil = handles.eyetrack.getpupil();
     
        
        %******* This is where to perform TimeStamp Syncing (start of trial)
        STARTCLOCK = handles.FC.prep_run_trial([ex,ey],pupil);
        STARTCLOCKTIME = GetSecs;
        
        %THIS IS AN INPUT STROBE: NEED TO SEND A MESSAGE TO THE EYETRACKERS / INPUTS
        for i=1:length(handles.inputs)
            handles.inputs{i}.starttrial(STARTCLOCK,STARTCLOCKTIME);
        end

         % TODO: OUTPUT STROBING GOES HERE
        for i=1:length(handles.outputs)
            handles.outputs{i}.starttrial(STARTCLOCK,STARTCLOCKTIME);
        end
        
       
      
        %%%%% Start trial loop %%%%%
        rewardtimes = [];
        runloop = 1;
        %****** added to control when juice drop is delivered based on graphics
        %****** demands, drop juice on frames with low demands basically
        screenTime = GetSecs;
        frameTime = (0.5/handles.S.frameRate);
        holdrop = 0;
        dropreject = 0;
        %**************
        while runloop

            state = PR.get_state();

            %%%%% GET INPUT VALUES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % TODO: REPLACE WITH INPUTS
            % THIS SHOULD ALSO BE WHERE IT CHECKS IF IT ALREADY HAS THEM
            % (i.e., replay)
            for i=1:length(handles.inputs)
                %Load other inputs here?
                handles.inputs{i}.readinput(handles.inputs{i});
            end
            [ex,ey] = handles.eyetrack.getgaze();
            pupil = handles.eyetrack.getpupil();
            

            % can we pass a state handle of some sort without overhead?
            [currentTime,x,y] = handles.FC.grabeye_run_trial(state,[ex,ey],pupil);
            % TODO: this is the place where from these values on, everything should
            % be determined from this point.
            %**********************************

            % THIS IS THE MAIN PROTOCOL STATE UPDATE METHOD
            %"DROP" is a droplet of juice
            drop = PR.state_and_screen_update(currentTime,x,y,handles.inputs);
            % TODO: DECISION on whether inputs should be handled within
            % PR.state_and_screen_update. Probably yes, but not eyetracker?
            
            % treadmill, this should be handled by the relevant
            % PR.state_and_screen_update with inputs
            %TODO: move to state_and_screen_update?
            %drop = handles.treadmill.afterFrame(currentTime, drop);

            %Additional independant rewards based on inputs (eg treadmill
            %distance)
            for i=1:length(handles.inputs)
                drop = handles.inputs{i}.afterFrame(currentTime, drop);
            end


            %******* before the next screen flush (since drop command takes time). only deliver drop if there is alot of time
            % Don't give a drop of juice if it will drop a frame
            if ( drop > 0)
                holdrop = 1;
                dropreject = 0;
            end

            if  (holdrop > 0)
                droptime = GetSecs;
                if ( (droptime-screenTime) < frameTime) || (dropreject > 12)
                    holdrop = 0;
                    rewardtimes = [rewardtimes droptime];
                    handles.reward.deliver();
                else
                    dropreject = dropreject + 1;
                end
            end


            %**********************************
            % EYE DISPLAY (SHOWEYE), SCREEN FLIP, and
            % ANY GUI UPDATING (if not time sensitive states)
            [updateGUI,screenTime] = handles.FC.screen_update_run_trial(state);

            %********* returns the time of screen flip **********
            if updateGUI
                drawnow;  % regrettable that this has to be included to grab the pause button hit
                % Update any changes made to the calibration
                handles = guidata(hObject);
                %*** pass update back into task controller
                A.c = handles.A.c;
                A.dx = handles.A.dx;
                A.dy = handles.A.dy;
                handles.FC.update_eye_calib(A.c,A.dx,A.dy);
            end

            runloop = PR.continue_run_trial(screenTime);
        end
            
        % TODO: END OF TRIAL SEND ALL MESSAGES
        %******** Update eye trace window before ITI start
        ENDCLOCK = handles.FC.last_screen_flip();   % set screen to gray, trial over, start ITI
        ENDCLOCKTIME = GetSecs;

        % TODO: LOOPE OVER INPUTS AND OUTPUTS AND STROBE SPECIFIC EVENTS
        
        %THIS IS AN INPUT STROBE: NEED TO SEND A MESSAGE TO THE EYETRACKERS / INPUTS
        for i=1:length(handles.inputs)
            handles.inputs{i}.endtrial((handles.inputs{i}),ENDCLOCK,ENDCLOCKTIME);
        end

         % TODO: OUTPUT STROBING GOES HERE
        for i=1:length(handles.outputs)
            handles.outputs{i}.endtrial((handles.inputs{i}),ENDCLOCK,ENDCLOCKTIME);
        end
        

        
        %******** Any final clean-up for PR in the trial
        Iti = PR.end_run_trial();
        
        %*************************************************************
        % PLOT THE EYETRACE and enforce an ITI interval
        itiStart = GetSecs;
        
        subplot(handles.EyeTrace); hold off;  % clear old plot

        PR.plot_trace(handles); hold on; % command to plot on eye traces 
        
        handles.FC.plot_eye_trace_and_flips(handles);  %plot the eye traces

        % eval(handles.plotCmd);
        while (GetSecs < (itiStart + Iti))
            drawnow;   % grab GUI events while running ITI interval    
            handles = guidata(hObject);
        end
        %*************************************
        
        % UPDATE HANDLES FROM ANY CHANGES DURING RUN TRIAL
        guidata(hObject,handles);
        % ALLOW OTHER CALLBACKS INTO THE QUEUE AND UPDATE HANDLES
        pause(.001); handles = guidata(hObject);
            
        % SKETCH OF MY DATA SOLUTION HERE
        %  D should be a struct that stores per trial data (not everything)
        %    D.P has trial parameters (struct)
        %    D.eyeData has the eye trace (matrix)
        %    D.PR has feedback from the protocol (struct)
        %       if the protocol is complicated (rev cor), this could be large
        %       for example, might list every stim shown per frame in trial
        %    D.C has the eye calibration (struct)
        % ******************************
        %  In this scenario, the PR.end_plots does not get D at all.
        %  What does that mean, if your PR wants to plot stats over trials
        %  then it must store its own internal D with that information in
        %  a list .... so the experimenter needs to police this function.  
        %  It will get the P struct and A each trial and can update then.
        
        %********* Some Data is uploaded automatically from Task Controller
        D = struct;
        D.P = P; % THE TRIAL PARAMETERS
        D.STARTCLOCKTIME = STARTCLOCKTIME;
        D.ENDCLOCKTIME = ENDCLOCKTIME;
        D.STARTCLOCK = STARTCLOCK;
        D.ENDCLOCK = ENDCLOCK;
        
        D.PR = PR.end_plots(P,A);   %if critical trial info save as D.PR
        
        if ~handles.runImage
            D.PR.name = handles.S.protocol;
            if (D.PR.error == 0)
                CorCount = CorCount + 1;
            end
        else
            D.PR.name = 'BackImage';
        end

        D.eyeData = handles.FC.upload_eyeData();
        [c,dx,dy] = handles.FC.upload_C();
        D.c = c;
        D.dx = dx;
        D.dy = dy;
        D.rewardtimes = rewardtimes;    % log the time of juice pulses
        D.juiceButtonCount = handles.A.juiceCounter; % SUPPLEMENTARY JUICE DURING THE TRIAL
        D.juiceVolume = A.juiceVolume; % THE VOLUME OF JUICE PULSES DURING THE TRIAL
        D.juiceUnits = A.juiceUnits; % THE units OF JUICE PULSES DURING THE TRIAL
 
        %Save all inputs and outputs
        D.inputs = (handles.inputs); % do we need to use the copy function?
        D.outputs = (handles.outputs); %

        %Save Calibration, it can change per trial
        D.C=    handles.C;


        %***************
        % SAVE THE DATA
        % here is a place to think as well ... what is the best way to save D?
        % can we append to a Matlab file only those parts news to the trial??
        % cd(handles.outputPath);             % goto output directory
        Dstring = sprintf('D%d',A.j);       % will store trial data in this variable
        eval(sprintf('%s = D;',Dstring));   % set variable 
        save(fullfile(handles.outputPath, A.outputFile),'-append','S',Dstring);   % append file
        % cd(handles.taskPath);               % return to task directory
        
        eval(sprintf('clear %s;',Dstring));
        clear D;                 % release the memory for D once saved
        %************** END OF THE TRIAL DATA SECTION *************************
        
        % UPDATE TRIAL COUNT AND FINISH NUMBER
        A.j = A.j+1;
        handles.TrialCountText.String = num2str(A.j-1);
        
        if ~handles.runOneTrial
            A.finish = handles.A.finish;
            handles.TrialMaxText.String = num2str(A.finish);
        end
        
        % UPDATE IN CASE JUICE VOLUME WAS CHANGED DURING END TRIAL
        % TODO: HANDLE ALL FEEDBACK HERE

        if handles.A.juiceVolume ~= A.juiceVolume
            fprintf(A.pump,['0 VOL ' num2str(A.juiceVolume/1000)]);
            set(handles.JuiceVolumeText,'String',[num2str(A.juiceVolume) A.juiceUnits]);
        end

        % UPDATE THE TASK RELATED STRUCTURES IN CASE OF LEAVING THE RUN LOOP
        handles.A = A;
        if ~handles.runImage
            handles.S = S;
            handles.P = P;
        else
            handles.SI = S;
            handles.PI = P;
        end

        %****** if it was an interleave Image trial, set it back proper
        if (SetRunBack == 1)
            handles.runImage = false;
            SetRunBack = 0;
            S = handles.S;
            P = handles.P;
            CorCount = 0;
        end

        %************************************
    
        % UPDATE THE PARAMETER LIST TO SHOW THE NEXT TRIAL PARAMETERS
        % NOTE, if running background image it is not listing the params
        %  but rather than main protocols params, in P struct, not PI struct
        for i = 1:size(handles.pNames,1)
            pName = handles.pNames{i};
            tName = sprintf('%s = %2g',pName,handles.P.(pName));
            handles.pList{i,1} = tName;
        end
        set(handles.Parameters,'String',handles.pList);

        % UPDATE THE HANDLES STRUCTURE FROM ALL OF THESE CHANGES
        guidata(hObject,handles);
        % ALLOW OTHER CALLBACKS INTO THE THE QUEUE. IF PARAMETERS ARE CHANGED
        % BY CHANCE THIS LATE IN THE LOOP, THEY WILL NOT BE CHANGED UNTIL
        % REACHING THE END OF THE NEXT TRIAL, BECAUSE P HAS ALREADY BEEN
        % ESTABLISHED FOR THE NEXT TRIAL. IF YOU EXIT THE LOOP, THOUGH, THEN P
        % WILL BE UPDATED BY ANY CHANGES TO THE HANDLES
        pause(.001); handles = guidata(hObject);

        % STOP RUN TASK IF SET TO DO SO
        if handles.stopTask || handles.runOneTrial
            handles.runTask = false;
        end
    end

    
    % handles.eyetrack.pause();
    %%%
    % TODO: make sure this pause method exists
    for i = 1:numel(handles.inputs)
        handles.inputs{i}.pause();
    end
    %******************************

    % NO TASK RUNNING FLAGS SHOULD BE ON ANYMORE
    handles.runTask = false;
    handles.stopTask = false;

    % UPDATE THE PARAMETERS LIST IN CASE OF ANY CHANGES MADE AFTER RUNNING THE
    % END TRIAL COMMAND
    for i = 1:size(handles.pNames,1)
        pName = handles.pNames{i};
        tName = sprintf('%s = %2g',pName,handles.P.(pName));
        handles.pList{i,1} = tName;
    end
    handles.Parameters.String = handles.pList;

    %********* TURN GUI BACK ON
    % set(jWindow,'Enable',1);  %turns off everything, figure is halted

    %********* Optional Turn Offs *****************
    %****** Gray out controls so it is clear you can't press them
    handles.RunTrial.Enable = 'On';
    handles.FlipFrame.Enable = 'On';
    handles.Background_Image.Enable = 'On';
    handles.Calib_Screen.Enable = 'On';
    handles.CloseGui.Enable = 'On';
    handles.ClearSettings.Enable = 'On';
    handles.OutputPrefixEdit.Enable = 'Off';
    % handles.OutputSubjectEdit.Enable = 'On';
    handles.OutputDateEdit.Enable = 'Off';
    handles.OutputSuffixEdit.Enable = 'Off';
    %********** even more turned off
    handles.Parameters.Enable = 'On';
    handles.TrialMaxEdit.Enable = 'On';
    handles.JuiceVolumeEdit.Enable = 'On';
    handles.ChooseSettings.Enable = 'Off';
    handles.Initialize.Enable = 'Off';
    handles.ParameterEdit.Enable = 'On';

    %********* Optional Turn Offs *****************
    %****** These might remain on for calib eye
    % TODO: check this
%     if ~handles.S.DummyEye
%     EnableEyeCalibration(handles,'On');
%     end

    %********** leave the pause button functioning **
    set(handles.PauseTrial,'Enable','Off');

    %***********************************************
    UpdateEyeText(handles);

    % UPDATE GUI STATUS
    handles.StatusText.String = 'Protocol is ready to run trials.';
    % SET TASK LIGHT TO RED
    ChangeLight(handles.TaskLight,[1 0 0]);

    % UPDATE HANDLES STRUCTURE
    guidata(hObject,handles);


    % STOP THE TRIAL LOOP ONCE THE CURRENT TRIAL HAS COMPLETED
function PauseTrial_Callback(hObject, eventdata, handles)
    % Pause button can also act as an unpause button
    if ~handles.stopTask
        handles.stopTask = true;
        % SET TASK LIGHT TO ORANGE
        ChangeLight(handles.TaskLight,[.9 .7 .2]);
    end
    % UPDATE HANDLES STRUCTURE
    guidata(hObject,handles);


% GIVE A JUICE REWARD
function GiveJuice_Callback(hObject, eventdata, handles)
    handles.reward.deliver();
    handles.A.juiceCounter = handles.A.juiceCounter + 1;
    guidata(hObject,handles);


% CHANGE THE SIZE OF THE JUICE REWARD TO BE DELIVERED
function JuiceVolumeEdit_CreateFcn(hObject, eventdata, handles) %#ok<*INUSD>
function JuiceVolumeEdit_Callback(hObject, eventdata, handles)
    vol = get(hObject,'String'); % volume is entered in microliters!!
    
    volUL = str2double(vol); % microliters
    
    % fprintf(handles.A.pump,['0 VOL ' volML]);
    handles.reward.volume = volUL; % milliliters
    if handles.S.solenoid
        set(handles.JuiceVolumeText,'String',[vol ' ms']); % displayed in microliters!!
    else
        set(handles.JuiceVolumeText,'String',[vol ' ul']);
    end
    set(hObject,'String',''); % why?
    handles.A.juiceVolume = volUL; % <-- A.juiceVolume should *always* be in milliliters!
    guidata(hObject,handles);


% RESETS THE DISPLAY SCREEN IF IT WAS INTERUPTED (BY E.G. ALT-TAB)
function FlipFrame_Callback(hObject, eventdata, handles)
    % If a bkgd parameter exists, flip frame with background color value
    if isfield(handles.P,'bkgd')
        Screen('FillRect',handles.A.window,uint8(handles.P.bkgd));
    end
    Screen('Flip',handles.A.window);


%%%%% PARAMETER CONTROL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Parameters_CreateFcn(hObject, eventdata, handles)
function Parameters_Callback(hObject, eventdata, handles)
    % Get the index of the selected field
    i = get(hObject,'Value');
    % Set the parameter text to a description of the parameter
    set(handles.ParameterText,'String',handles.S.(handles.pNames{i}));
    % Set the parameter edit to the current value of that parameter
    set(handles.ParameterEdit,'String',num2str(handles.P.(handles.pNames{i})));
    % Update handles structure
    guidata(hObject,handles);

function ParameterEdit_CreateFcn(hObject, eventdata, handles)
function ParameterEdit_Callback(hObject, eventdata, handles)
    % Get the new parameter value
    pValue = str2double(get(hObject,'String'));
    % Get the parameter name
    pName = handles.pNames{get(handles.Parameters,'Value')};
    % If the parameter value is a number
    if ~isnan(pValue)
        % Change the parameter value
        handles.P.(pName) = pValue;
        % Update the parameter list immediately if not in the run loop
        if ~handles.runTask
            tName = sprintf('%s = %2g',pName,handles.P.(pName));
            handles.pList{get(handles.Parameters,'Value')} = tName;
            set(handles.Parameters,'String',handles.pList);
        end
    
%         % handle treadmill parameters
%         if any(strfind(pName, 'tread'))
%             tName = pName(6:end);
%             handles.treadmill.(tName) = handles.P.(pName);
%         end
    else
        % Revert the parameter text to the previous value
        set(hObject,'String',num2str(handles.P.(pName)));
    end
    % Update handles structure
    guidata(hObject,handles);

function TrialMaxEdit_CreateFcn(hObject, eventdata, handles)
function TrialMaxEdit_Callback(hObject, eventdata, handles)
    % Get the new count
    newFinal = round(str2double(get(hObject,'String')));
    % Make sure the new final trial is a positive integer
    if newFinal > 0
        % Update the final trial
        handles.A.finish = newFinal;
        % Set the count
        set(handles.TrialMaxText,'String',get(hObject,'String'));
    end
    % Clear the edit string
    set(hObject,'String','');
    
    % Update handles structure
    guidata(hObject,handles);

%%%%% SHIFT EYE POSITION CALLBACKS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function CenterEye_Callback(hObject, eventdata, handles)
    [x,y] = handles.eyetrack.getgaze();
    handles.A.c = [x,y];
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function GainSize_CreateFcn(hObject, eventdata, handles)
function GainSize_Callback(hObject, eventdata, handles)
    gainSize = str2double(get(hObject,'String'));
    if ~isnan(gainSize)
        handles.gainSize = gainSize;
        guidata(hObject,handles);
    else
        set(handles.GainSize,'String',num2str(handles.gainSize));
    end

function GainUpX_Callback(hObject, eventdata, handles)
    % Note we divide by dx, so reducing dx increases gain
    handles.A.dx = (1-handles.gainSize)*handles.A.dx;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function GainDownX_Callback(hObject, eventdata, handles)
    handles.A.dx = (1+handles.gainSize)*handles.A.dx;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function GainUpY_Callback(hObject, eventdata, handles)
    handles.A.dy = (1-handles.gainSize)*handles.A.dy;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function GainDownY_Callback(hObject, eventdata, handles)
    handles.A.dy = (1+handles.gainSize)*handles.A.dy;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);


function ShiftSize_CreateFcn(hObject, eventdata, handles)
function ShiftSize_Callback(hObject, eventdata, handles)
    shiftSize = str2double(get(hObject,'String'));
    if ~isnan(shiftSize)
        handles.shiftSize = shiftSize;
        guidata(hObject,handles);
    else
        set(handles.ShiftSize,'String',num2str(handles.shiftSize));
    end

function ShiftLeft_Callback(hObject, eventdata, handles)
    handles.A.c(1) = handles.A.c(1) + ...
        handles.shiftSize*handles.A.dx*handles.S.pixPerDeg;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function ShiftRight_Callback(hObject, eventdata, handles)
    handles.A.c(1) = handles.A.c(1) - ...
        handles.shiftSize*handles.A.dx*handles.S.pixPerDeg;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function ShiftDown_Callback(hObject, eventdata, handles)
    handles.A.c(2) = handles.A.c(2) + ...
        handles.shiftSize*handles.A.dy*handles.S.pixPerDeg;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function ShiftUp_Callback(hObject, eventdata, handles)
    handles.A.c(2) = handles.A.c(2) - ...
        handles.shiftSize*handles.A.dy*handles.S.pixPerDeg;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function ResetCalibration_Callback(hObject, eventdata, handles)
    handles.A.dx = handles.C.dx;
    handles.A.dy = handles.C.dy;
    handles.A.c = handles.C.c;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

%%%%% OUTPUT PANEL CALLBACKS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function OutputPrefixEdit_CreateFcn(hObject, eventdata, handles)
function OutputPrefixEdit_Callback(hObject, eventdata, handles)
    handles.outputPrefix = get(hObject,'String');
    handles = UpdateOutputFilename(handles);
    guidata(hObject,handles);

function OutputSubjectEdit_CreateFcn(hObject, eventdata, handles)
function OutputSubjectEdit_Callback(hObject, eventdata, handles)
    handles.outputSubject = get(hObject,'String');
    handles.S.subject = handles.outputSubject;
    handles = UpdateOutputFilename(handles);
    guidata(hObject,handles);

function OutputDateEdit_CreateFcn(hObject, eventdata, handles)
function OutputDateEdit_Callback(hObject, eventdata, handles)
    handles.outputDate = get(hObject,'String');
    handles = UpdateOutputFilename(handles);
    guidata(hObject,handles);

function OutputSuffixEdit_CreateFcn(hObject, eventdata, handles)
function OutputSuffixEdit_Callback(hObject, eventdata, handles)
    handles.outputSuffix = get(hObject,'String');
    handles = UpdateOutputFilename(handles);
    guidata(hObject,handles);

%%%%% CLOSE THE GUI %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function CloseGui_Callback(hObject, eventdata, handles)
    % Close all screens from ptb
    sca;
    % If Data File Open, condense appended D's into one struct ****
    CondenseAppendedData(hObject,handles);
    % Close the pump
    handles.reward.report()
    delete(handles.reward); handles.reward = NaN;
    
    % Save any changes to the calibration
    c = handles.A.c; %#ok<NASGU>    Supressing editor errors because theses
    dx = handles.A.dx; %#ok<NASGU>  variables are being saved
    dy = handles.A.dy; %#ok<NASGU>
%     if ~handles.S.DummyEye
%         save(fullfile(handles.supportPath, 'MarmoViewLastCalib.mat'),'c','dx','dy');
%     end

    %CLOSE ALL INPUTS AND OUTPUTS
    for i=1:length(handles.inputs)
        handles.inputs{i}.close;
    end

    for i=1:length(handles.outputs)
        handles.outputs{i}.close;
    end

%     %********** if using the DataPixx, close it here
%     if (handles.S.DataPixx)
%         datapixx.close();
%     end
%     IOPort('CloseAll')
%     if isa(handles.eyetrack, 'marmoview.eyetrack_ddpi')
%         ddpiM('stop')
%         ddpiM('shutdown')
%     end
    IOPort('CloseAll')
    % Close the gui window
    close(handles.figure1);

%%%%% AUXILLIARY FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ChangeLight(h,col)
    % THIS FUNCTION CHANGES THE TASK LIGHT
    scatter(h,.5,.5,600,'o','MarkerEdgeColor','k','MarkerFaceColor',col);
    axis(h,[0 1 0 1]); bkgd = [.931 .931 .931];
    set(h,'XColor',bkgd,'YColor',bkgd,'Color',bkgd);

% THIS FUNCTION UPDATES THE RAW EYE CALIBRATION NUMBERS IN THE GUI
function UpdateEyeText(h)
    set(h.CenterText,'String',sprintf('[%.3g %.3g]',h.A.c(1),h.A.c(2)));
    dx = 100*h.A.dx; dy = 100*h.A.dy; % A LARGE MAGNIFICATION IS USED TO EFFICIENTLY DISPLAY 2 DIGITS
    set(h.GainText,'String',sprintf('[%.3g %.3g]',dx,dy));

% THIS FUNCTION UPDATES PLOTS OF THE EYE TRACE
function UpdateEyePlot(handles)
    if ~handles.runTask && handles.A.j > 1   % At least 1 trial must be complete in order to plot the trace
        subplot(handles.EyeTrace); hold off;  % clear old plot
        if ~handles.lastRunWasImage
            handles.PR.plot_trace(handles); hold on; % command to plot on eye traces
        else
            handles.PRI.plot_trace(handles); hold on; % command to plot on eye traces
        end
        handles.FC.plot_eye_trace_and_flips(handles);  %plot the eye traces
    end

function handles = UpdateOutputFilename(handles)
    % Generate the file name
    if (~isempty(handles.outputPrefix) && ~isempty(handles.outputSubject) && ...
            ~isempty(handles.outputDate) && ~isempty(handles.outputSuffix) )
        handles.A.outputFile = strcat(handles.outputPrefix,'_',handles.outputSubject,...
            '_',handles.outputDate,'_',handles.outputSuffix,'.mat');
        set(handles.OutputFile,'String',handles.A.outputFile);
        % If the file name already exists, provide a warning that data will be
        % overwritten
        if exist([handles.outputPath handles.A.outputFile],'file')
            w=warndlg('Data file alread exists, running the trial loop will overwrite.');
            set(w,'Position',[441.75 -183 270.75 75.75]);
        end
        % Note that a new output file is being used. For example, someone might
        % want to be sure the trials list is started over if the output file name
        % changes. Currently I don't have any protocols implementing this.
        handles.A.newOutput = 1;
    else
        if ( ~isempty(handles.outputSubject) && ~strcmp(handles.outputSubject,'none') )
            %****** then it should be possible to initialize a protocol with name
            set(handles.SettingsPanel,'Visible','on');
            if ~exist([handles.settingsPath handles.settingsFile],'file')
                set(handles.Initialize,'Enable','off');
                tstring = 'Please select a settings file...';
            else
                set(handles.Initialize,'Enable','on');
                tstring = 'Ready to initialize protocol...';
            end
            % Update GUI status
            set(handles.StatusText,'String',tstring);
            %*******************************************
        end
    end

%********* Turn on or off all controls related to eye calibration
%        state should be a string, 'On' or 'Off'
function EnableEyeCalibration(handles,state)
    handles.CenterEye.Enable = state;
    handles.ShiftUp.Enable = state;
    handles.ShiftDown.Enable = state;
    handles.ShiftLeft.Enable = state;
    handles.ShiftRight.Enable = state;
    handles.GainUpY.Enable = state;
    handles.GainDownY.Enable = state;
    handles.GainUpX.Enable = state;
    handles.GainDownX.Enable = state;
    handles.ShiftSize.Enable = state;
    handles.GainSize.Enable = state;
    handles.ResetCalibration.Enable = state;
    handles.GraphZoomIn.Enable = state;
    handles.GraphZoomOut.Enable = state;

% --- Executes on button press in Calib_Screen.
function Calib_Screen_Callback(hObject, eventdata, handles)
    % hObject    handle to Calib_Screen (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    
    % If a bkgd parameter exists, flip frame with background color value
    % Screen('FillRect',handles.A.window,uint8(0));
    % Screen('Flip',handles.A.window);
    handles.runImage = true;
    handles.runOneTrial = true; % keep running till paused, or true stop at one
    hold_dir = handles.SI.ImageDirectory;
    handles.PRI.load_image_dir(['SupportData',filesep,'ForagePoint']);
    guidata(hObject,handles);
    RunTrial_Callback(hObject, eventdata, handles)
    % it appears if handles changed, you need to regrab it
    % what lives in this function is the old copy of it
    handles = guidata(hObject);
    %**********
    handles.runImage = false;
    handles.runOneTrial = false;
    handles.PRI.load_image_dir(hold_dir);
    guidata(hObject,handles);


% --- Executes on button press in Background_Image.
function Background_Image_Callback(hObject, eventdata, handles)
    % hObject    handle to Background_Image (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    
    % Idea is the following, turn on flag and run PRI object instead
    % of the PR object, otherwise data logging and other tracking identical
    handles.runImage = true;
    handles.runOneTrial = true; % keep running till paused, or true stop at one
    guidata(hObject,handles);
    RunTrial_Callback(hObject, eventdata, handles)
    % it appears if handles changed, you need to regrab it
    % what lives in this function is the old copy of it
    handles = guidata(hObject);
    %**********
    handles.runImage = false;
    handles.runOneTrial = false;
    guidata(hObject,handles);


% --- Executes on button press in GraphZoomIn.
function GraphZoomIn_Callback(hObject, eventdata, handles)
    % hObject    handle to GraphZoomIn (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    if handles.eyeTraceRadius > 2.5
        handles.eyeTraceRadius = handles.eyeTraceRadius-2.5;
    end
    guidata(hObject,handles);
    UpdateEyePlot(handles);


% --- Executes on button press in GraphZoomOut.
function GraphZoomOut_Callback(hObject, eventdata, handles)
    % hObject    handle to GraphZoomOut (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    if handles.eyeTraceRadius < 30
        handles.eyeTraceRadius = handles.eyeTraceRadius+2.5;
    end
    guidata(hObject,handles);
    UpdateEyePlot(handles);


% --- Executes on button press in Refresh_Trials.
function Refresh_Trials_Callback(hObject, eventdata, handles)
    % hObject    handle to Refresh_Trials (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    
    %REBUILD A NEW TRIALS LIST FROM CURRENT PARAMS
    handles.PR.generate_trialsList(handles.S,handles.P);
    % DE-INITIALIZE OBJECTS (may need to make new if Param changed)
    handles.PR.closeFunc();
    % RE-INITIALIZE OBJECTS (may need to make new if Param changed)
    handles.PR.initFunc(handles.S,handles.P);
    %******* load changes in handles back to the GUI
    guidata(hObject,handles);


%******** We store trial by trial data while running
%******** but before closing, we condense it back to
%******** a single D struct.
%******** NOTE: if MarmoView hangs or crashes, you would
%******** still be able to call this routine on what is saved
function CondenseAppendedData(hObject, handles)
           
    guidata(hObject,handles); drawnow;
    A = handles.A;   % get the A struct (carries output file names)

    %******* go to outputPath and load current data
    if ~strcmp(A.outputFile,'none')  % could be in state with no open file
        
        % Copy mfile as of time of running for worst case scenario recovery
        % Cost is a few kB, per trial can grow large, so we want to do it once
        fPR=fopen([handles.taskPath filesep '+protocols' filesep 'PR_' handles.S.protocol '.m']);
        %D.PR_mfile=fread(fPR);
        PR_mfile=fread(fPR);
        fclose(fPR);


        %cd(handles.outputPath);             % goto output directory
        if exist(A.outputFile,'file')
            NewOutput = [A.outputFile(1:(end-4)),'z.mat'];
            fprintf('Condensing data for file %s to %s\n',A.outputFile,NewOutput);
            zdata = load(A.outputFile);    % load in all data
            S = zdata.S;                   % get settings struct
            D = cell(1,1);
            ND = length(fields(zdata));      % includes all trials, minus one for S
            for k = 1:(ND-1)
                Dstring = sprintf('D%d',k);
                D{k,1} = zdata.(Dstring);
            end
            clear zdata;
            %********
            save(fullfile(handles.outputPath,NewOutput),'S','D','PR_mfile');   % append file
            clear D;
            fprintf('Data file %s reformatted.\n',NewOutput);
        end
        %cd(handles.taskPath);            % return to task directory
    end



% --- Executes on slider movement.
function slider_P4intensity_Callback(hObject, eventdata, handles)
    % hObject    handle to slider_P4intensity (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    if isa(handles.eyetrack, 'marmoview.eyetrack_ddpi')
        handles.eyetrack.p4intensity = hObject.Value;
        ddpiM('setP4Template', [handles.eyetrack.p4intensity, handles.eyetrack.p4radius]);
        fprintf('Setting P4 intensity to: %f\n',  handles.eyetrack.p4intensity)
    end
    % Hints: get(hObject,'Value') returns position of slider
    %        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider_P4intensity_CreateFcn(hObject, eventdata, handles)
    % hObject    handle to slider_P4intensity (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called
    
    % Hint: slider controls usually have a light gray background.
    if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor',[.9 .9 .9]);
    end

% --- Executes on slider movement.
function slider_P4radius_Callback(hObject, eventdata, handles)
    % hObject    handle to slider_P4radius (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    
    if isa(handles.eyetrack, 'marmoview.eyetrack_ddpi')
        handles.eyetrack.p4radius = hObject.Value;
        ddpiM('setP4Template', [handles.eyetrack.p4intensity, handles.eyetrack.p4radius]);
        fprintf('Setting P4 radius to: %f\n',  handles.eyetrack.p4radius)
    end
    % Hints: get(hObject,'Value') returns position of slider
    %        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider_P4radius_CreateFcn(hObject, eventdata, handles)
    % hObject    handle to slider_P4radius (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called
    
    % Hint: slider controls usually have a light gray background.
    if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor',[.9 .9 .9]);
    end
