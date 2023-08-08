classdef MarmoV6 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        MarmoV6UIFigure       matlab.ui.Figure
        ResetGUI              matlab.ui.control.Button
        Image                 matlab.ui.control.Image
        ParameterPanel        matlab.ui.container.Panel
        Refresh_Trials        matlab.ui.control.Button
        TrialMaxEdit          matlab.ui.control.EditField
        TrialMaxText          matlab.ui.control.Label
        TrialCountText        matlab.ui.control.Label
        TrialMaxLabel         matlab.ui.control.Label
        TrialCountLabel       matlab.ui.control.Label
        ParameterEdit         matlab.ui.control.EditField
        ParameterText         matlab.ui.control.Label
        Parameters            matlab.ui.control.ListBox
        AuthorText            matlab.ui.control.Label
        StatusText            matlab.ui.control.Label
        TaskPerformancePanel  matlab.ui.container.Panel
        DataPlot4             matlab.ui.control.UIAxes
        DataPlot3             matlab.ui.control.UIAxes
        DataPlot2             matlab.ui.control.UIAxes
        DataPlot1             matlab.ui.control.UIAxes
        OutputPanel           matlab.ui.container.Panel
        OutputFile            matlab.ui.control.Label
        OutputSuffixLabel     matlab.ui.control.Label
        OutputDateLabel       matlab.ui.control.Label
        OutputSubjectLabel    matlab.ui.control.Label
        OutputPrefixLabel     matlab.ui.control.Label
        OutputSuffixEdit      matlab.ui.control.EditField
        OutputDateEdit        matlab.ui.control.EditField
        OutputSubjectEdit     matlab.ui.control.EditField
        OutputPrefixEdit      matlab.ui.control.EditField
        EyeTrackerPanel       matlab.ui.container.Panel
        text31                matlab.ui.control.Label
        slider_P4radius       matlab.ui.control.Slider
        slider_P4intensity    matlab.ui.control.Slider
        text30                matlab.ui.control.Label
        GraphZoomOut          matlab.ui.control.Button
        GraphZoomIn           matlab.ui.control.Button
        text29                matlab.ui.control.Label
        ResetCalibration      matlab.ui.control.Button
        GainText              matlab.ui.control.Label
        CenterText            matlab.ui.control.Label
        CenterEye             matlab.ui.control.Button
        CalibFilename         matlab.ui.control.Label
        GainSize              matlab.ui.control.EditField
        GainUpY               matlab.ui.control.Button
        GainDownY             matlab.ui.control.Button
        GainDownX             matlab.ui.control.Button
        GainUpX               matlab.ui.control.Button
        text7                 matlab.ui.control.Label
        text2                 matlab.ui.control.Label
        ShiftSize             matlab.ui.control.EditField
        ShiftUp               matlab.ui.control.Button
        ShiftDown             matlab.ui.control.Button
        ShiftLeft             matlab.ui.control.Button
        ShiftRight            matlab.ui.control.Button
        EyeTrace              matlab.ui.control.UIAxes
        SettingsPanel         matlab.ui.container.Panel
        Background_Image      matlab.ui.control.Button
        Calib_Screen          matlab.ui.control.Button
        SettingsFile          matlab.ui.control.Label
        ClearSettings         matlab.ui.control.Button
        Initialize            matlab.ui.control.Button
        ChooseSettings        matlab.ui.control.Button
        ProtocolTitle         matlab.ui.control.Label
        CloseGui              matlab.ui.control.Button
        ControlsPanel         matlab.ui.container.ButtonGroup
        FlipFrame             matlab.ui.control.Button
        JuiceVolumeText       matlab.ui.control.Label
        JuiceVolumeEdit       matlab.ui.control.EditField
        GiveJuice             matlab.ui.control.Button
        PauseTrial            matlab.ui.control.Button
        RunTrial              matlab.ui.control.Button
        TaskLight             matlab.ui.control.UIAxes
        Title                 matlab.ui.control.Label
    end

    properties (GetAccess = public, SetAccess = public)
        %Properties that can be stored to app, but can be changed by other
        %functions. Eg calibration mats run on the fly
        A
    end

    properties (GetAccess = public, SetAccess = private)
        %We need the stimuli and protocol code to have access to the data
        %in the app, but we want to ensure that everything is predetermined
        %and stored before jumping into a protocol to draw a frame. Ie we
        %don't want to set stimuli parameters then have the protocol
        %overwrite them each trial
        %
        taskPath % Description
        settingsPath
        outputPath
        supportPath
        settingsFile
        eyeTraceRadius
        
        S
        P
        PR

        SI
        PI
        PRI

        FC

        inputs
        outputs
        reward
        eyetrack
        eyetrackername

        outputSubject % is this suppose to be a text property 
        C
        shiftSize
        gainSize
        calibFile

        pNames
        pList
        iList

        % Can we intialise here instead of openfnc?
        runTask = false;
        stopTask = false;
        %******** New parameters for running background image
        runOneTrial = false;
        runImage = false;
        lastRunWasImage = false;

        %Holdover, we should just call the fields directly?
        outputPrefix = [];
        outputDateEdit = [];
        outputSuffixEdit = [];
        outputDate
        outputSuffix

    end
    
    
    methods (Access = private)
        function ChangeLight(app, h, col)
                % THIS FUNCTION CHANGES THE TASK LIGHT
                scatter(h,.5,.5,600,'o','MarkerEdgeColor','k','MarkerFaceColor',col);
                axis(h,[0 1 0 1]); bkgd = [.931 .931 .931];
                set(h,'XColor',bkgd,'YColor',bkgd,'Color',bkgd);
        end
        
        function CondenseAppendedData(app)
            
            %guidata(hObject,handles); drawnow;
            A = app.A;   % get the A struct (carries output file names)
        
            %******* go to outputPath and load current data
            if ~strcmp(A.outputFile,'none')  % could be in state with no open file
        
                % Copy mfile as of time of running for worst case scenario recovery
                % Cost is a few kB, per trial can grow large, so we want to do it once
                fPR=fopen([app.taskPath filesep '+protocols' filesep 'PR_' app.S.protocol '.m']);
                %D.PR_mfile=fread(fPR);
                PR_mfile=fread(fPR);
                fclose(fPR);
        
        
                %cd(app.outputPath);             % goto output directory
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
                    save(fullfile(app.outputPath,NewOutput),'S','D','PR_mfile');   % append file
                    clear D;
                    fprintf('Data file %s reformatted.\n',NewOutput);
                end
                %cd(app.taskPath);            % return to task directory
            end
        end
        
        function EnableEyeCalibration(app, state)
            app.CenterEye.Enable = state;
            app.ShiftUp.Enable = state;
            app.ShiftDown.Enable = state;
            app.ShiftLeft.Enable = state;
            app.ShiftRight.Enable = state;
            app.GainUpY.Enable = state;
            app.GainDownY.Enable = state;
            app.GainUpX.Enable = state;
            app.GainDownX.Enable = state;
            app.ShiftSize.Enable = state;
            app.GainSize.Enable = state;
            app.ResetCalibration.Enable = state;
            app.GraphZoomIn.Enable = state;
            app.GraphZoomOut.Enable = state;
        end
        
        function UpdateEyePlot(app)
            if ~app.runTask && app.A.j > 1   % At least 1 trial must be complete in order to plot the trace
                subplot(app.EyeTrace); hold off;  % clear old plot
                if ~app.lastRunWasImage
                    app.PR.plot_trace(app); hold on; % command to plot on eye traces
                else
                    app.PRI.plot_trace(app); hold on; % command to plot on eye traces
                end
                app.FC.plot_eye_trace_and_flips(app);  %plot the eye traces
            end
        end

        function UpdateEyeText(app)
            set(app.CenterText,'Text',sprintf('[%.3g %.3g]',app.A.c(1),app.A.c(2)));
            dx = app.A.dx; dy = app.A.dy; %Not multiplying anymore (used to be 100x for readability)
            set(app.GainText,'Text',sprintf('[%.3g %.3g]',dx,dy));
        end

        function UpdateOutputFilename(app)
            % Generate the file name
            if (~isempty(app.outputPrefix) && ~isempty(app.outputSubject) && ...
                    ~isempty(app.outputDate) && ~isempty(app.outputSuffix) )
                app.A.outputFile = strcat(app.outputPrefix,'_',app.outputSubject,...
                    '_',app.outputDate,'_',app.outputSuffix,'.mat');
                set(app.OutputFile,'Text',app.A.outputFile);
                % If the file name already exists, provide a warning that data will be
                % overwritten
                if exist([app.outputPath app.A.outputFile],'file')
                    w=warndlg('Data file alread exists, running the trial loop will overwrite.');
                    set(w,'Position',[441.75 -183 270.75 75.75]);
                end
                % Note that a new output file is being used. For example, someone might
                % want to be sure the trials list is started over if the output file name
                % changes. Currently I don't have any protocols implementing this.
                app.A.newOutput = 1;
            else
                if ( ~isempty(app.outputSubject) && ~strcmp(app.outputSubject,'none') )
                    %****** then it should be possible to initialize a protocol with name
                    set(app.SettingsPanel,'Visible', 1);
                    if ~exist([app.settingsPath app.settingsFile],'file')
                        set(app.Initialize,'Enable', 0);
                        tstring = 'Please select a settings file...';
                    else
                        set(app.Initialize,'Enable', 1);
                        tstring = 'Ready to initialize protocol...';
                    end
                    % Update GUI status
                    set(app.StatusText,'Text',tstring);
                    %*******************************************
                end
            end
            

        
        end
      
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Ensure that the app appears on screen when run
            movegui(app.MarmoV6UIFigure, 'onscreen');
            
        
            %%%%% IMPORTANT GROUNDWORK FOR THE GUI IS PLACED HERE %%%%%%%%%%%%%%%%%%%%%
        
            % GET SOME CRUCIAL DIRECTORIES -- THESE DIRECTORIES MUST EXIST!!
            % Present working directory, location of all GUIs
            app.taskPath = fileparts(mfilename('fullpath'));
            % Settings directory, settings files should be kept here
            app.settingsPath = fullfile(app.taskPath, 'Settings');
            % Output directory, all data will be saved here!
            app.outputPath = fullfile(app.taskPath, 'Output');
            % Support data directory, data to support MarmoV6 or its protocols can be
            % kept here unintrusively (e.g. eye calibration values or marmoset images)
            app.supportPath = fullfile(app.taskPath, 'SupportData');
            %****** start with no settings file
            app.settingsFile = 'none';
            set(app.SettingsFile,'Text',app.settingsFile);
        
        
            % TODO: should be eyetracker and subject dependent, so we need to first
            % load up rig settings and subject name
        %     app.calibFile = 'MarmoViewLastCalib.mat';
        %     set(app.CalibFilename,'Text',app.calibFile);
        %
        %     if exist(app.calibFile, 'file')
        %         tmp = load([app.supportPath filesep app.calibFile]);
        %         app.C.dx = tmp.dx;
        %         app.C.dy = tmp.dy;
        %         app.C.c = tmp.c;
        %     else
        %         app.C.dx = .1;
        %         app.C.dy = .1;
        %         app.C.c = [0 0];
        %     end
        
            app.eyeTraceRadius = 15;
            % This C structure is never changed until a protocol is cleared or
            % MarmoV6 is exited, until then, it may be reset to the C values using
            % the ResetCalib callback.
        
            % CREATE THE STRUCTURES USED BY ALL PROTOCOLS
            app.A = struct; % Values necessary for protocols to run current trial
            app.S = struct; % Settings for the protocol, NOT changed while running
            app.P = struct; % Parameters for the current protocol, changeable
        
        
            % TODO: do we want to handle the images this way??
            app.SI = app.S;
            app.PI = struct;
        
            %****** AT SOME POINT THIS TASK CONTROL MAY INCLUDE EPHYS TIMING WRAPPER
            app.FC = marmoview.FrameControl();   % create generic task control
        
            % LOAD RIG SETTINGS TO S, THIS IS RELOADED FOR EACH PROTOCOL, SO IT SHOULD
            % BE LOCATED IN A DIRECTORY IN MATLAB'S PATH, I SUGGEST THE
            % 'MarmoV6\SupportFunctions' DIRECTORY
            app.outputSubject = 'none';
            S = MarmoViewRigSettings;
            S.subject = app.outputSubject;
            app.S = S;
        
        
        
            % Add in the plot handles to A in case handles isn't available
            % e.g. while running protocols)
            app.A.EyeTrace = app.EyeTrace;
            app.A.DataPlot1 = app.DataPlot1;
            app.A.DataPlot2 = app.DataPlot2;
            app.A.DataPlot3 = app.DataPlot3;
            app.A.DataPlot4 = app.DataPlot4;
            app.A.outputFile = 'none';
        
        
            % -------------------------------------------------------------------------
            % --- Inputs (e.g., eyetracking, treadmill, mouse, etc.)
            numInputs = numel(S.inputs);
            app.inputs = cell(numInputs,1);
        
            eyechecker=0;
            for i = 1:numInputs
                assert(ismember(app.S.inputs{i}, fieldnames(app.S)), 'MarmoV6.m line 139: requested input needs field of that name')
                app.inputs{i} = marmoview.(app.S.inputs{i})(app.S.(app.S.inputs{i}));
        
                %cellfun
                if app.inputs{i}.UseAsEyeTracker
                    %Set up app.eyetrack for direct calls later
                    app.eyetrack=app.inputs{i};
                    app.eyetrackername=app.S.inputs{i};
                    eyechecker=eyechecker+1;
        
                    %Will load calibration after subject is entered
                end
            end
            assert(eyechecker==1,'MarmoV6 ln 776: one and only one input can be the active eyetracker method')
        

        
        
            % -------------------------------------------------------------------------
            % --- Outputs (e.g., datapixx, synchronization routines, etc.)
            numOutputs = numel(S.outputs);
            app.outputs = cell(numOutputs,1);
            for i = 1:numOutputs
                assert(ismember(app.S.outputs{i}, fieldnames(app.S)), 'MarmoV6.m line 148: requested outputs needs parameter struct field of that name')
                app.outputs{i} = marmoview.(app.S.outputs{i})(app.S.(app.S.outputs{i}));
            end
        
            %Set up a generic eyetrack class to be filled with an input and a
            %generic reward class to be filled with an output
            %app.eyetrack = marmoview.eyetrack();
            app.reward = marmoview.(app.S.feedback{1})(app.S.(app.S.feedback{1}));
            % TODO: Figure out best way to do this
        
            app.A.juiceVolume   = app.reward.volume;
            app.A.juiceUnits    = app.reward.units;
        
            app.A.juiceCounter = 0; % Initialize, juice counter is reset when loading a protocol
        
            %********************************************************
            %EYEDUMP PLOTTING OF EYETRACKING
% 
%             %******** ADDED VIA SHAUN ************************
%             %******* and then Arrington wrapper by Jude ******
%             if isfield(app.S, 'eyetracker') && ischar(app.S.eyetracker)
%                 switch app.S.eyetracker
%                     case 'OpenIris'
%                         app.eyetrack = marmoview.eyetrack_OpenIris(hObject,'EyeDump',S.EyeDump);
%                     case 'arrington'
%                         app.eyetrack = marmoview.eyetrack_arrington(hObject,'EyeDump',S.EyeDump);
%                     case 'ddpi'
%                         app.eyetrack = marmoview.eyetrack_ddpi(hObject,'EyeDump',S.EyeDump);
%                     case 'eyelink'
%                         % if EYELINK, you must wait until initializing the protocol to setup
%                         % the eye tracker .... for now, set it to a default object
%                         app.eyetrack = marmoview.eyetrack();
%                         app.S.eyelink = true;
%                     otherwise
%                         app.eyetrack = marmoview.eyetrack();
%                 end
%             else % dump to the old version
%                 
%                 if app.S.arrington % create an @arrington eyetrack object for eye position
%                     app.eyetrack = marmoview.eyetrack_arrington(hObject,'EyeDump',S.EyeDump);
%                 elseif app.S.eyelink
%                     % if EYELINK, you must wait until initializing the protocol to setup
%                     % the eye tracker .... for now, set it to a default object
%                     app.eyetrack = marmoview.eyetrack();
%                 else % no eyetrack, use @eyetrack object instead that uses mouse pointer
%                     app.eyetrack = marmoview.eyetrack();
%                 end
%             end


            %********* add the task controller for storing eye movements, flipping
            %********* frames
            % WRITE THE CALIBRATION DATA INTO THE EYE TRACKER PANEL AND GET THE SIZES
            % OF GAIN AND SHIFT CONTROLS FOR CALIBRATING EYE POSITION
            % FOR UPDATE EYE TEXT TO RUN PROPPERLY, CALBIRATION MUST ALREADY BE IN
            % STRUCTURE 'A'

            %Do this in initiallise function instead
%             UpdateEyeText(app);
%             app.shiftSize = str2double(get(app.ShiftSize,'Value'));
%             app.gainSize = str2double(get(app.GainSize,'Value'));
        
            % THESE VARIABLES CONTROL THE RUN LOOP
            % already intiallised, remove?
            app.runTask = false;
            app.stopTask = false;
            %******** New parameters for running background image
            app.runOneTrial = false;
            app.runImage = false;
            app.lastRunWasImage = false;
        
            % SET ACCESS TO GUI CONTROLS
            app.Initialize.Enable = 'Off';
            app.ClearSettings.Enable = 'Off';
            app.RunTrial.Enable = 'Off';
            app.PauseTrial.Enable = 'Off';
            app.FlipFrame.Enable = 'Off';
            app.Background_Image.Enable = 'Off';
            app.Calib_Screen.Enable = 'Off';
            app.ParameterPanel.Visible = 'Off';
            app.EyeTrackerPanel.Visible = 'Off';
            app.TaskPerformancePanel.Visible = 'Off';
            app.SettingsPanel.Visible = 'Off';
        
            % Force to select subject name first thing
            app.OutputPrefixEdit.Enable = false;
            app.OutputSubjectEdit.Value = 'none';
            app.outputSubject = 'none';
        
            app.OutputDateEdit.Enable = false;
            app.OutputSuffixEdit.Enable = false;
            %****** set names to empty for starting
            app.outputPrefix = [];
            app.outputDateEdit = [];
            app.outputSuffixEdit = [];
            %**************
            tstring = 'Please select SUBJECT to begin';
            app.StatusText.Text = tstring;

            % For the protocol title, note that no protocol has been loaded yet
            app.ProtocolTitle.Text = 'No protocol is loaded.';

            %TODO add back in functions
            % The task light is a neutral gray when no protocol is loaded
            ChangeLight(app, app.TaskLight,[.5 .5 .5]);
           % UpdateEyeText(app)
            
        end

        % Button pushed function: Background_Image
        function Background_ImageButtonPushed(app, eventdata)
            % This might not work the same way, previously it stored
            % guidata into a hObject ran an image, then restored the
            % hObject
            
            % Idea is the following, turn on flag and run PRI object instead
            % of the PR object, otherwise data logging and other tracking identical
            app.runImage = true;
            app.runOneTrial = true; % keep running till paused, or true stop at one
            %guidata(hObject,handles);
            %RunTrial_Callback(app, eventdata)

            app.RunTrial.ButtonPushedFcn(app, eventdata)
            % it appears if handles changed, you need to regrab it
            % what lives in this function is the old copy of it
            %handles = guidata(hObject);
            %**********
            app.runImage = false;
            app.runOneTrial = false;
            %guidata(hObject,handles);
        end

        % Value changed function: OutputSubjectEdit
        function OutputSubjectEditValueChanged(app, event)
            value = app.OutputSubjectEdit.Value;
            app.outputSubject = value;
            app.S.subject = value;
            UpdateOutputFilename(app);


            
            %% Now that we have all the parameters, we can load a calibration

            %find most recent calibration with that eyetracker, subject
            %Calibdir=dir(fullfile(app.supportPath, app.eyetrack, app.outputSubject))

            % Calibdir = dir(fullfile(app.supportPath,(app.S.inputs{i}), '*Calib.mat'));
            % Or just prepend filename with tracker?
            
            TrackerSubjFile = dir(fullfile(app.supportPath,'Calibrations',[(app.eyetrackername) '_' app.outputSubject '_Calib.mat']));
            TrackerFile     = dir(fullfile(app.supportPath,'Calibrations',[(app.eyetrackername) '_Calib.mat']));
            if ~isempty(TrackerSubjFile)
                app.calibFile= TrackerSubjFile(TrackerSubjFile.datenum==min(TrackerSubjFile.datenum)).name;
                tmp = load(fullfile(TrackerSubjFile.folder,app.calibFile));
%                 exist(app.calibFile, 'file')
%                 tmp = load([app.supportPath filesep app.calibFile]);
                app.C.dx = tmp.dx;
                app.C.dy = tmp.dy;
                app.C.c = tmp.c;
            elseif ~isempty(TrackerFile)
                app.calibFile= TrackerFile.name(min(TrackerFile.datenum));
                tmp = load(fullfile(TrackerSubjFile.folder,app.calibFile));
%                 exist(app.calibFile, 'file')
%                 tmp = load([app.supportPath filesep app.calibFile]);
                app.C.dx = tmp.dx;
                app.C.dy = tmp.dy;
                app.C.c = tmp.c;
            else
                %Default calibration for that eyetracker
                app.C=app.eyetrack.calibinit(app.S);
            end
            % Load calibration variables into the A structure to be changed if needed
            app.A.dx = app.C.dx;
            app.A.dy = app.C.dy;
            app.A.c = app.C.c;

            UpdateEyeText(app);
            app.shiftSize = str2double(get(app.ShiftSize,'Value'));
            app.gainSize = str2double(get(app.GainSize,'Value'));

        end

        % Button pushed function: Initialize
        function InitializeButtonPushed(app, event)
            % PREPARE THE GUI FOR INITIALIZING THE PROTOCOL
            %This is a big one

            % Update GUI status
            set(app.StatusText,'Text','Initializing...');
            % The task light is blue only during protocol initialization
            ChangeLight(app, app.TaskLight,[.2 .2 1]);
        
            % TURN OFF BUTTONS TO PREVENT FIDDLING DURING INITIALIZATION
            set(app.ChooseSettings,'Enable', 0);
            set(app.Initialize,'Enable', 0);
            set(app.OutputSubjectEdit,'Enable', 0); % subject already set
            % Effect these changes on the GUI immediately
            %guidata(hObject, handles); drawnow;
        
            % GET PROTOCOL SETTINGS
            % TODO: DON'T Do This
            cd(app.settingsPath);
            cmd = sprintf('[app.S,app.P] = %s;',app.settingsFile(1:end-2));
            eval(cmd);
            app.S.subject = app.outputSubject;
            cd(app.taskPath);
        

            % MOVE THE GUI OFF OF THE VISUAL STIMULUS SCREEN TO THE CONSOLE SCREEN
            % THIS IS CHANGED IN PROTOCOL SETTINGS AND IS NOT A NECESSARY SETTING
            if isfield(app.S,'guiLocation')
                set(app.MarmoV6UIFigure,'Position',app.S.guiLocation);
            end
        
            % SHOW THE PROTOCOL TITLE
            set(app.ProtocolTitle,'Text',app.S.protocolTitle);
        
            % OPEN THE PTB SCREEN
            app.A = marmoview.openScreen(app.S,app.A);
        
            % INITIALIZE THE PROTOCOL
            % TODO: Dynamic calls
        %     protocols.(app.S.protocol_class)
            cmd = sprintf('app.PR = %s(app.A.window);',app.S.protocol_class);
            eval(cmd);   %Establishes the PR object
        
            %***************
            % GENERATE DEFAULT TRIALS LIST
            app.PR.generate_trialsList(app.S,app.P);
            %*****************
            app.PR.initFunc(app.S, app.P);
            %***************
        
            % ALSO GENERATE A BACKGROUND IMAGE VIEWER PROTOCOL
            %********* Setup Image Viewer Protocol ******************
            % TODO: Don't change directories
            cd(app.settingsPath);
            [app.SI,app.PI] = BackImage;
            cd(app.taskPath);
            % INITIALIZE THE Back Image Protocol
            app.PRI = protocols.PR_BackImage(app.A.window);
            app.PRI.generate_trialsList(app.SI,app.PI);
            app.PRI.initFunc(app.SI, app.PI);
            %***************
        
            %*****************************************
        
            % INITIALIZE THE TASK CONTROLLER FOR THE TRIAL
            app.FC.initialize(app.A.window, app.P, app.C, app.S);
        
            % SET UP THE OUTPUT PANEL
            % Get the output file name components
            app.outputPrefix = app.S.protocol;
            set(app.OutputPrefixEdit,'Value',app.outputPrefix);
            set(app.OutputSubjectEdit,'Value',app.outputSubject);
            app.outputDate = char(datetime('today', 'format', 'ddMMyy'));
            set(app.OutputDateEdit,'Value',app.outputDate);
            i = 0; app.outputSuffix = '00';
            % Generate the file name
            app.A.outputFile = strcat(app.outputPrefix,'_',app.outputSubject,...
                '_',app.outputDate,'_',app.outputSuffix,'.mat');
            % If the file name already exists, iterate the suffix to a nonexistant file
            while exist(fullfile(app.outputPath,app.A.outputFile),'file') %exist([app.outputPath app.A.outputFile],'file')
                i = i+1; app.outputSuffix = num2str(i,'%.2d');
                app.A.outputFile = strcat(app.outputPrefix,'_',app.outputSubject,...
                    '_',app.outputDate,'_',app.outputSuffix,'.mat');
            end
        


        %TODO: DO WE NEED THIS BLOCK (.init) IF EVERYTHING GETS INITIALISED
        %ON FIRST CALL ALREADY

            % --- initialize inputs
            % This should start recording on the eye trackers / make sure
            % synchronization is ready
            for i = 1:numel(app.inputs)
                app.inputs{i}.startfile(); %app.A.outputFile
            end
            
            % initialize outputs
            for i = 1:numel(app.outputs)
                app.outputs{i}.startfile(app);%app.A.outputFile
            end
        %
        
            % Show the file name on the GUI
            app.OutputSuffixEdit.Value = app.outputSuffix;
            app.OutputFile.Text = app.A.outputFile;
        
            % Note that a new output file is being used
            app.A.newOutput = 1;
        
            % SET UP THE PARAMETERS PANEL
            % Trial counting section of the parameters
            app.A.j = 1; app.A.finish = app.S.finish;
            app.TrialCountText.Text = ['Trial ' num2str(app.A.j-1)];
            app.TrialMaxText.Text = num2str(app.A.finish);
            app.TrialMaxEdit.Value = '';
        
            % Get strings for the parameters list
            app.pNames = fieldnames(app.P);         % pNames are the actual parameter names
            app.pList = cell(size(app.pNames,1),1); % pList is the list of parameter names with values
            for i = 1:size(app.pNames,1)
                pName = app.pNames{i};
                tName = sprintf('%s = %2g',pName,app.P.(pName));
                app.pList{i,1} = tName;
                %app.pList{i,1} = app.pNames{i};
                app.iList{i,1} = i;%app.P.(pName);
            end
        
            % add parameters to GUI
            app.Parameters.Items        = app.pList;%app.pList;
            app.Parameters.ItemsData    = app.iList;%
            % For the highlighted parameter, provide a description and editable value
            %app.Parameters.Value = app.Parameters.Items{1};
            app.ParameterText.Text = app.S.(app.pNames{1});
            app.ParameterEdit.Value = num2str(app.P.(app.pNames{1}));
        
            % UPDATE ACCESS TO CONTROLS
            app.RunTrial.Enable = 'on';
            app.FlipFrame.Enable = 'On';
            app.ClearSettings.Enable ='On';
            app.ParameterPanel.Visible ='On';
            app.EyeTrackerPanel.Visible = 'On';
            app.OutputPanel.Visible = 'On';
            app.OutputSubjectEdit.Enable = 'Off';
            app.OutputPrefixEdit.Enable = 'Off';
            app.OutputDateEdit.Enable = 'Off';
            app.OutputSuffixEdit.Enable = 'Off';
            app.TaskPerformancePanel.Visible = 'On';
            app.Background_Image.Enable = 'On';
            app.Calib_Screen.Enable = 'On';
        
            %******* allow for graph zoom in and out
            app.GraphZoomIn.Enable = 'On';
            app.GraphZoomOut.Enable = 'On';
        
            %*******Blank the eyetrace plot
            h = app.EyeTrace;
            eyeRad = app.eyeTraceRadius;
            set(h,'NextPlot','Replace');
            plot(h,0,0,'+k','LineWidth',2);
            set(h,'NextPlot','Add');
            plot(h,[-eyeRad eyeRad],[0 0],'--','Color',[.5 .5 .5]);
            plot(h,[0 0],[-eyeRad eyeRad],'--','Color',[.5 .5 .5]);
            axis(h,[-eyeRad eyeRad -eyeRad eyeRad]);
            %*************************
        
       
        
            % UPDATE GUI STATUS
            set(app.StatusText,'Text','Protocol is ready to run trials.');
            % Now that a protocol is loaded (but not running), task light is red
            ChangeLight(app, app.TaskLight,[1 0 0]);
        
            % FINALLY, RESET THE JUICE COUNTER WHENEVER A NEW PROTOCOL IS LOADED
            app.A.juiceCounter = 0;
        
            % Bring gui to front, does this actually work?
            movegui(app.MarmoV6UIFigure, 'onscreen');

            % UPDATE HANDLES STRUCTURE
            %guidata(hObject,handles);
        end

        % Button pushed function: ChooseSettings
        function ChooseSettingsButtonPushed(app, event)
            %create a dummy figure so that uigetfile doesn't minimize our GUI
            decoy = figure('Position', [-100 -100 0 0]); 

            % Have user select the file
            app.settingsFile = uigetfile([app.settingsPath filesep]);
            delete(decoy); %delete the dummy figure

            % Show the selected outputfile
            if app.settingsFile ~= 0
                set(app.SettingsFile,'Text',app.settingsFile);
            else
            % Or no outputfile if cancelled selection
                set(app.SettingsFile,'Text','none');
                app.settingsFile = 'none';
            end

            % If file exists, then we can get the protocol initialized
            if exist(app.settingsFile,'file')
                if (strcmp(app.outputSubject,'none'))
                   set(app.Initialize,'Enable',0);
                   tstring = 'Please select SUBJECT NAME >>>';
                else
                   set(app.Initialize,'Enable',1);
                   tstring = 'Ready to initialize protocol...';
                end
            else
                set(app.Initialize,'Enable',0);
                tstring = 'Please select a settings file...';
            end

            % Regardless, update status
            set(app.StatusText,'Text',tstring);
        
            % Bring gui to front, should stay now that we aren't
            % changing directories. But still disappears!
            movegui(app.MarmoV6UIFigure, 'onscreen');
            
           
            % Update handles structure
            %guidata(hObject, handles);            
        end

        % Button pushed function: RunTrial
        function RunTrialButtonPushed(app, event)
            % SET THE TASK TO RUN
            app.runTask = true;
            
            %********* store what is the current EyeTrace to plot, based on
            %********* what protocol is most recently called (image or other)
            if ~app.runImage
                app.lastRunWasImage = false;
            else
                app.lastRunWasImage = true;
            end
            %****************************
            
            % SET TASK LIGHT TO GREEN
            ChangeLight(app, app.TaskLight,[0 1 0]);
            %*********
            
            %****** NOTE, maybe you can turn off some graphics figure features
            %******  like resize and move functions in the future
            
            %****** Gray out controls so it is clear you can't press them
            app.RunTrial.Enable = 'Off';
            app.FlipFrame.Enable ='Off';
            app.Background_Image.Enable = 'Off';
            app.Calib_Screen.Enable = 'Off';
            app.CloseGui.Enable = 'Off';
            app.ClearSettings.Enable = 'Off';
            app.ChooseSettings.Enable = 'Off';
            app.Initialize.Enable = 'Off';
            app.OutputPrefixEdit.Enable = 'Off';
            % app.OutputSubjectEdit.Enable = 'Off';
            app.OutputDateEdit.Enable = 'Off';
            app.OutputSuffixEdit.Enable = 'Off';
            %********** even more turned off
            app.Parameters.Enable = 'Off';
            app.TrialMaxEdit.Enable = 'Off';
            app.JuiceVolumeEdit.Enable = 'Off';
            app.ChooseSettings.Enable = 'Off';
            app.Initialize.Enable = 'Off';
            app.ParameterEdit.Enable = 'Off';
            %********* Optional Turn Offs *****************
            %****** These might remain on for calib eye
            %     if ( isfield(app.P,'InTrialCalib') && (app.P.InTrialCalib == 1) && ...
            %             (~app.S.DummyEye) )  %dont allow calibration if dummy screen (use mouse)
            %       if ~app.S.DummyEye
            %          EnableEyeCalibration(handles,'On');
            %       else
            %          EnableEyeCalibration(handles,'Off');
            %          app.GraphZoomIn.Enable = 'On';
            %          app.GraphZoomOut.Enable = 'On';
            %       end
            %       UpdateEyeText(handles);
            %     else
            %       EnableEyeCalibration(handles,'Off');
            %       UpdateEyeText(handles);
            %     end
            if isfield(app.P,'InTrialCalib') && (app.P.InTrialCalib == 1)
                %dont allow calibration if dummy screen (use mouse)
            %       if ~app.S.DummyEye
            %          EnableEyeCalibration(handles,'On');
            %       else
                                
%                 EnableEyeCalibration(app,'Off');
                EnableEyeCalibration(app,'On');
                app.GraphZoomIn.Enable = 'On';
                app.GraphZoomOut.Enable = 'On';
                UpdateEyeText(app);
            else
              EnableEyeCalibration(app,'Off');
              UpdateEyeText(app);
            end
            
            %********** leave the pause button functioning **
            app.PauseTrial.Enable = 'On';
            %***********************************************
            
            % TODO: do we want to log data when MarmoV6 is paused
            % unpause the inputs
            for i = 1:numel(app.inputs)
                app.inputs{i}.unpause(app.inputs{i});
            end
            
            %********************************
            
            % UPDATE GUI STATUS
            set(app.StatusText,'Text','Protocol trials are running.');
            
            % RESET THE JUICER COUNTER BEFORE ENTERING THE RUN LOOP
            app.A.juiceCounter = 0;
%             % UPDATE THE HANDLES
%             guidata(hObject,handles); drawnow;
            
            % MOVE TASK RELATED STRUCTURES OUT OF HANDLES FOR THE RUN LOOP -- this way
            % if a callback interrupts the run task function, we can update any changes
            % the interrupting callback makes to handles without affecting those task
            % related structures. E.g. we can run the task using parameters as they
            % were at the start of the trial, while getting ready to cue any changes
            % the user made on the next trial.
            A = app.A;   % these structs are small enough we will pass them
            if ~app.runImage
                S = app.S;   % as arguments .... don't make them huge ... larger
                P = app.P;   % data should stay in D, or inside the PR or FC objects
            else
                S = app.SI;  % pull other arguments for image protocol
                P = app.PI;
            end
            % IF NOT DATA FILE OPENED, CREATE AND INSERT S Struct first
            %****** ONCE OPENED, YOU ONLY APPEND TO THAT FILE EACH TRIAL NEW DATA
            if ~exist(A.outputFile)
                save(fullfile(app.outputPath, A.outputFile),'S');     % save settings struct to output file
            end
            
            %****** pass in any updated calibration params (can calib when paused!)
            app.FC.update_eye_calib(A.c,A.dx,A.dy);
            %****** also, check if user turned on showEye during a pause
            app.FC.update_args_from_Pstruct(P);  %showEye, eyeIntensity, eye Radius, ...
            %*********************************
            
            % RUN TRIALS
            CorCount = 0;   % count consecutive correct trials (for BackImage interleaving)
            SetRunBack = 0; % flag for swapping to interleaved image trials and back
            %*******
            
            while app.runTask && A.j <= A.finish
                % 'pause', 'drawnow', 'figure', 'getframe', or 'waitfor' will allow
                % other callbacks to interrupt this run task callback -- be aware that
                % if handles aren't properly managed then changes either in the run
                % loop or in other parts of the GUI may be out-of-sync. Nothing changes
                % to GUI-wide handles until the local callback puts them there. If
                % other callbacks change handles, and they are not brought into this
                % callback, then those changes are lost when this run loop updates that
                % app. This concept is explained further right below during the
                % nextCmd handles management.
            
                %******* Check if automatic interleaving of BackImage trials
                %******* and set the trial accordingly
                if isfield(app.P,'CycleBackImage')
                    if app.P.CycleBackImage > 0
                        if ~mod((CorCount+1),app.P.CycleBackImage)
                            app.runImage = true;
                            SetRunBack = 1;
                            S = app.SI;
                            P = app.PI;
                        end
                    end
                end
            
                %*****************************
                P.rng_before_trial = rng(); % save current state of the random number generator
            
                % set which protocol to use
                %     if isa(PR, 'protocols.protocol')
                %         PR = copy(PR); % unlink PR from app.PR
                %     end
                % TODO: does this still make sense
                if app.runImage
                    PR = app.PRI;
                else
                    PR = app.PR;
                end
            
            
                % EXECUTE THE NEXT TRIAL COMMAND
                P = PR.next_trial(S,P);
            
                % UPDATE IN CASE JUICE VOLUME WAS CHANGED USING A PARAMETER
                % TODO: Does this make sense anymore: app.A and A are the
                % same handle now
                if app.A.juiceVolume ~= A.juiceVolume
                    app.A.juiceVolume = A.juiceVolume;
                end
            
                % UPDATE HANDLES FROM ANY CHANGES DURING NEXT TRIAL -- IF THIS ISN'T
                % DONE, THEN THE OTHER CALLBACKS WILL BE USING A DIFFERENT HANDLES
                % STRUCTURE THAN THIS LOOP IS

                % TODO: NEED TO CLARIFY HOW .MLAPP GUI HANDLES THIS!!!
%                 guidata(hObject,handles);


                % ALLOW OTHER CALLBACKS INTO THE QUEUE AND UPDATE HANDLES --
                % HERE, HAVING UPDATED ANY RUN LOOP CHANGES TO HANDLES, WE LET OTHER
                % CALLBACKS DO THEIR THING. WE THEN GRAB THOSE HANDLES SO THE RUN LOOP
                % IS ON THE SAME PAGE. FORTUNATELY, IF A PARAMETER CHANGES IN HANDLES,
                % THAT WON'T AFFECT THE CURRENT TRIAL WHICH IS USING 'P', NOT app.P
                pause(.001); %handles = guidata(hObject);
            
                %******** IMPLEMENT DEFAULT RUN TRIAL HERE DIRECTLY **********
                %***** Note, PR will refer to the PROTOCOL object ************
                [FP,TS] = PR.prep_run_trial();
            
                app.FC.set_task(FP,TS);  % load values into class for plotting (FP)
                                            % and to label TimeSensitive states (TS)
            
                %Eyetracking input object should
                %already be set up
                app.eyetrack.readinput();
                [ex,ey] = app.eyetrack.getgaze();
                pupil = app.eyetrack.getpupil();
            
            
                %******* This is where to perform TimeStamp Syncing (start of trial)
                STARTCLOCK = app.FC.prep_run_trial([ex,ey],pupil);
                STARTCLOCKTIME = GetSecs;
            
                %THIS IS AN INPUT STROBE: NEED TO SEND A MESSAGE TO THE EYETRACKERS / INPUTS
                for i=1:length(app.inputs)
                    app.inputs{i}.starttrial(STARTCLOCK,STARTCLOCKTIME);
                    %app.inputs{i}.starttrial(app.inputs{i},STARTCLOCK,STARTCLOCKTIME);
                end
            
                 % TODO: OUTPUT STROBING GOES HERE
                for i=1:length(app.outputs)
                    app.outputs{i}.starttrial(STARTCLOCK,STARTCLOCKTIME);
                end
            
            
                %%%%% Start trial loop %%%%%
                rewardtimes = [];
                runloop = 1;
                %****** added to control when juice drop is delivered based on graphics
                %****** demands, drop juice on frames with low demands basically
                screenTime = GetSecs;
                frameTime = (0.5/app.S.frameRate);
                holdrop = 0;
                dropreject = 0;
                %**************
                while runloop
            
                    state = PR.get_state();
            
                    %%%%% GET INPUT VALUES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % TODO: THIS SHOULD ALSO BE WHERE IT CHECKS IF IT
                    % ALREADY HAS INPUTS (i.e., for replay)
                    for i=1:length(app.inputs)
                        %Load other inputs here?
                        app.inputs{i}.readinput(app.inputs{i});
                    end
                    [ex,ey] = app.eyetrack.getgaze();
                    pupil = app.eyetrack.getpupil();
            
            
                    % can we pass a state handle of some sort without overhead?
                    [currentTime,x,y] = app.FC.grabeye_run_trial(state,[ex,ey],pupil);
                    % TODO: this is the place where from these point on, 
                    % values are locked in andeverything should be determined
                    %**********************************
                        
                    %%%% BALISTIC FROM HERE ON %%%%%%%%%%%%%%%%%%%%%%%%%%
            
                    % THIS IS THE MAIN PROTOCOL STATE UPDATE METHOD
                    %"DROP" is a droplet of juice, reward based on on state
                    %and state update 
                    drop = PR.state_and_screen_update(currentTime,x,y,app.inputs,app.outputs);
            
            
                    %Additional independant rewards based on inputs (eg treadmill
                    %distance)
                    for i=1:length(app.inputs)
                        drop = app.inputs{i}.afterFrame(currentTime, drop);
                    end
                    
                    %disp(drop)
            
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
                            app.reward.deliver();
                        else
                            dropreject = dropreject + 1
                        end
                    end
            
            
                    %**********************************
                    % EYE DISPLAY (SHOWEYE), SCREEN FLIP, and
                    % ANY GUI UPDATING (if not time sensitive states)
                    [updateGUI,screenTime] = app.FC.screen_update_run_trial(state);
            
                    %********* returns the time of screen flip **********
                    % TODO, need to know if this makes sense in appd format
                    if updateGUI
                        drawnow;  % regrettable that this has to be included to grab the pause button hit
                        % Update any changes made to the calibration
                        %handles = guidata(hObject);
                        %*** pass update back into task controller
                        A.c = app.A.c;
                        A.dx = app.A.dx;
                        A.dy = app.A.dy;
                        [A.c,A.dx,A.dy] ;
                        app.FC.update_eye_calib(A.c,A.dx,A.dy);
                    end
            
                    runloop = PR.continue_run_trial(screenTime);
                end
            
                % TODO: END OF TRIAL SEND ALL MESSAGES
                %******** Update eye trace window before ITI start
                ENDCLOCK = app.FC.last_screen_flip();   % set screen to gray, trial over, start ITI
                ENDCLOCKTIME = GetSecs;
            
                % TODO: LOOP OVER INPUTS AND OUTPUTS AND STROBE SPECIFIC EVENTS
            
                % THIS IS AN INPUT STROBE: NEED TO SEND A MESSAGE TO THE EYETRACKERS / INPUTS
                for i=1:length(app.inputs)
                    app.inputs{i}.endtrial((app.inputs{i}),ENDCLOCK,ENDCLOCKTIME);
                end
            
                 % TODO: OUTPUT STROBING GOES HERE
                for i=1:length(app.outputs)
                    app.outputs{i}.endtrial(ENDCLOCK,ENDCLOCKTIME);
                end
            
            
            
                %******** Any final clean-up for PR in the trial
                Iti = PR.end_run_trial();
            
                %*************************************************************
                % PLOT THE EYETRACE and enforce an ITI interval
                itiStart = GetSecs;
            
                %subplot(app.EyeTrace); hold off;  % clear old plot
                %axes(app.EyeTrace)
                hold(app.EyeTrace,'off')
                PR.plot_trace(app); hold(app.EyeTrace,'on')%hold on; % command to plot on eye traces
            
                app.FC.plot_eye_trace_and_flips(app);  %plot the eye traces
            
                % eval(app.plotCmd);
                while (GetSecs < (itiStart + Iti))
                    drawnow;   % grab GUI events while running ITI interval
                    %handles = guidata(hObject);
                end
                %*************************************
            
                % UPDATE HANDLES FROM ANY CHANGES DURING RUN TRIAL
                %guidata(hObject,handles);
                % ALLOW OTHER CALLBACKS INTO THE QUEUE AND UPDATE HANDLES
                pause(.001); %handles = guidata(hObject);
            
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
            
                if ~app.runImage
                    D.PR.name = app.S.protocol;
                    if (D.PR.error == 0)
                        CorCount = CorCount + 1;
                    end
                else
                    D.PR.name = 'BackImage';
                end
            
                D.eyeData = app.FC.upload_eyeData();
                [c,dx,dy] = app.FC.upload_C();
                D.c = c;
                D.dx = dx;
                D.dy = dy;
                D.rewardtimes = rewardtimes;    % log the time of juice pulses
                D.juiceButtonCount = app.A.juiceCounter; % SUPPLEMENTARY JUICE DURING THE TRIAL
                D.juiceVolume = app.A.juiceVolume; % THE VOLUME OF JUICE PULSES DURING THE TRIAL
                %D.juiceUnits = app.A.juiceUnits; % THE units OF JUICE PULSES DURING THE TRIAL
            
                %Save all inputs and outputs
                D.inputs = (app.inputs); % do we need to use the copy function?
                D.outputs = (app.outputs); %
            
                %Save Calibration, it can change per trial
                D.C=    app.C;
            
            
                %***************
                % SAVE THE DATA
                % here is a place to think as well ... what is the best way to save D?
                % can we append to a Matlab file only those parts news to the trial??
                % cd(app.outputPath);             % goto output directory
                Dstring = sprintf('D%d',A.j);       % will store trial data in this variable
                eval(sprintf('%s = D;',Dstring));   % set variable
                save(fullfile(app.outputPath, A.outputFile),'-append','S',Dstring);   % append file
                % cd(app.taskPath);               % return to task directory
            
                eval(sprintf('clear %s;',Dstring));
                clear D;                 % release the memory for D once saved
                %************** END OF THE TRIAL DATA SECTION *************************
            
                % UPDATE TRIAL COUNT AND FINISH NUMBER
                A.j = A.j+1;
                app.TrialCountText.Text = num2str(A.j-1);
            
                if ~app.runOneTrial
                    A.finish = app.A.finish;
                    app.TrialMaxText.Text = num2str(A.finish);
                end
            
                % UPDATE IN CASE JUICE VOLUME WAS CHANGED DURING END TRIAL
                % TODO: HANDLE ALL FEEDBACK HERE
            
                if app.A.juiceVolume ~= A.juiceVolume
                    fprintf(A.pump,['0 VOL ' num2str(A.juiceVolume/1000)]);
                    set(app.JuiceVolumeText,'Text',[num2str(A.juiceVolume) A.juiceUnits]);
                end
            
                % UPDATE THE TASK RELATED STRUCTURES IN CASE OF LEAVING THE RUN LOOP
                app.A = A;
                if ~app.runImage
                    app.S = S;
                    app.P = P;
                else
                    app.SI = S;
                    app.PI = P;
                end
            
                %****** if it was an interleave Image trial, set it back proper
                if (SetRunBack == 1)
                    app.runImage = false;
                    SetRunBack = 0;
                    S = app.S;
                    P = app.P;
                    CorCount = 0;
                end
            
                %************************************
            
                % UPDATE THE PARAMETER LIST TO SHOW THE NEXT TRIAL PARAMETERS
                % NOTE, if running background image it is not listing the params
                %  but rather than main protocols params, in P struct, not PI struct
                for i = 1:size(app.pNames,1)
                    pName = app.pNames{i};
                    tName = sprintf('%s = %2g',pName,app.P.(pName));
                    app.pList{i,1} = tName;
                end
                set(app.Parameters,'Items',app.pList);
            
                % UPDATE THE HANDLES STRUCTURE FROM ALL OF THESE CHANGES
                %guidata(hObject,handles);

                % ALLOW OTHER CALLBACKS INTO THE THE QUEUE. IF PARAMETERS ARE CHANGED
                % BY CHANCE THIS LATE IN THE LOOP, THEY WILL NOT BE CHANGED UNTIL
                % REACHING THE END OF THE NEXT TRIAL, BECAUSE P HAS ALREADY BEEN
                % ESTABLISHED FOR THE NEXT TRIAL. IF YOU EXIT THE LOOP, THOUGH, THEN P
                % WILL BE UPDATED BY ANY CHANGES TO THE HANDLES
                pause(.001); %handles = guidata(hObject);
            
                % STOP RUN TASK IF SET TO DO SO
                if app.stopTask || app.runOneTrial
                    app.runTask = false;
                end
            end
            
            
            % app.eyetrack.pause();
            %%%
            % TODO: make sure this pause method exists
            for i = 1:numel(app.inputs)
                app.inputs{i}.pause();
            end
            %******************************
            
            % NO TASK RUNNING FLAGS SHOULD BE ON ANYMORE
            app.runTask = false;
            app.stopTask = false;
            
            % UPDATE THE PARAMETERS LIST IN CASE OF ANY CHANGES MADE AFTER RUNNING THE
            % END TRIAL COMMAND
            for i = 1:size(app.pNames,1)
                pName = app.pNames{i};
                tName = sprintf('%s = %2g',pName,app.P.(pName));
                app.pList{i,1} = tName;
            end
            app.Parameters.Items = app.pList;
            
            %********* TURN GUI BACK ON
            % set(jWindow,'Enable',1);  %turns off everything, figure is halted
            
            %********* Optional Turn Offs *****************
            %****** Gray out controls so it is clear you can't press them
            app.RunTrial.Enable = 'On';
            app.FlipFrame.Enable = 'On';
            app.Background_Image.Enable = 'On';
            app.Calib_Screen.Enable = 'On';
            app.CloseGui.Enable = 'On';
            app.ClearSettings.Enable = 'On';
            app.OutputPrefixEdit.Enable = 'Off';
            % app.OutputSubjectEdit.Enable = 'On';
            app.OutputDateEdit.Enable = 'Off';
            app.OutputSuffixEdit.Enable = 'Off';
            %********** even more turned off
            app.Parameters.Enable = 'On';
            app.TrialMaxEdit.Enable = 'On';
            app.JuiceVolumeEdit.Enable = 'On';
            app.ChooseSettings.Enable = 'Off';
            app.Initialize.Enable = 'Off';
            app.ParameterEdit.Enable = 'On';
            
            %********* Optional Turn Offs *****************
            %****** These might remain on for calib eye
            % TODO: check this
            %     if ~app.S.DummyEye
            %     EnableEyeCalibration(handles,'On');
            %     end
            
            %********** leave the pause button functioning **
            set(app.PauseTrial,'Enable','Off');
            
            %***********************************************
            UpdateEyeText(app);
            
            % UPDATE GUI STATUS
            app.StatusText.Text = 'Protocol is ready to run trials.';
            % SET TASK LIGHT TO RED
            ChangeLight(app, app.TaskLight,[1 0 0]);
                       
        end

        % Button pushed function: ClearSettings
        function ClearSettingsButtonPushed(app, event)
            % DISABLE RUNNING THINGS WHILE CLEARING
            app.RunTrial.Enable = 'Off';
            app.FlipFrame.Enable = 'Off';
            app.ClearSettings.Enable = 'Off';
            app.ChooseSettings.Enable = 'On';
            app.Initialize.Enable = 'On';
            app.OutputPanel.Visible = 'Off';
            app.ParameterPanel.Visible = 'Off';
            app.EyeTrackerPanel.Visible = 'Off';
            app.OutputPanel.Visible = 'Off';
            app.TaskPerformancePanel.Visible = 'Off';
            app.Background_Image.Enable = 'Off';
            app.Calib_Screen.Enable = 'Off';
            
            % Clear plots
            plot(app.DataPlot1,0,0,'+k');
            plot(app.DataPlot2,0,0,'+k');
            plot(app.DataPlot3,0,0,'+k');
            plot(app.DataPlot4,0,0,'+k');
            
            % Eye trace needs to be treated differently to maintain important
            % properties
            plot(app.EyeTrace,0,0,'+k');
            app.EyeTrace.UserData = 15; % 15 degrees of visual arc is default
            
            
            %INPUT/OUTPUT closefiles
            for i=1:length(app.inputs)
                app.inputs{i}.closefile();
            end
            
            for i=1:length(app.outputs)
                app.outputs{i}.closefile(app);
            end
            
            %****** ADDED VIA SHAUN **********
            %%% SC: eye posn data
            % tell ViewPoint to close the eye posn data file
            % TODO: fix eye tracker specific
            %     app.eyetrack.closefile();
            %*************************
            
            % DE-INITIALIZE PROTOCOL (remove screens or objects created on init)
            app.PR.closeFunc();  % de-initialize any objects
            app.PRI.closeFunc(); % close the back-ground image protocol
            app.lastRunWasImage = false;
            
            
            % REFORMAT DATA FILES TO CONDENSED STRUCT
            CondenseAppendedData(app)
            
            % Close all screens from ptb
            sca;
            
            % Save the eye calibration values at closing time to the MarmoViewLastCalib
            c = app.A.c;
            dx = app.A.dx;
            dy = app.A.dy;
            
            % TODO: how do we want to handle calibration?
            %     if ~app.S.DummyEye
            %         save([app.supportPath 'MarmoViewLastCalib.mat'],'c','dx','dy');
            %     end
            % Create a structure for A that maintains only basic values required
            % outside the protocol
            app.C.c = c; app.C.dx = dx; app.C.dy = dy;
            A = app.C;
            A.EyeTrace = app.EyeTrace;
            A.DataPlot1 = app.DataPlot1;
            A.DataPlot2 = app.DataPlot2;
            A.DataPlot3 = app.DataPlot3;
            A.DataPlot4 = app.DataPlot4;
            A.outputFile = 'none';
            
            % Reset structures
            app.A = A;
            app.S = MarmoViewRigSettings;
            app.S.subject = app.outputSubject;
            app.P = struct;
            app.SI = app.S;
            app.PI = struct;
            
            % If juice delivery volume was changed during the previous protocol,
            % return it to default. Also add the juice counter for the juice button.
            % fprintf(app.A.pump,['0 VOL ' num2str(app.S.pumpDefVol)]);
            % app.reward.volume = app.S.pumpDefVol; % milliliters
            app.A.juiceVolume = app.reward.volume;
            app.A.juiceCounter = 0;
            set(app.JuiceVolumeText,'Text',sprintf('%3i ul',app.A.juiceVolume));
            
            
            % RE-ENABLE CONTROLS
            app.ChooseSettings.Enable = 'On';
            % Initialize is only available if the settings file exists
            app.settingsFile = get(app.SettingsFile,'Text');
            if ~exist([app.settingsPath app.settingsFile],'file')
                app.Initialize.Enable = 'off';
                tstring = 'Please select a settings file...';
            else
                app.Initialize.Enable = 'on';
                tstring = 'Ready to initialize protocol...';
            end
            % Update GUI status
            app.StatusText.Text = tstring;
            % For the protocol title, note that no protocol is now loaded
            app.ProtocolTitle.Text = 'No protocol is loaded.';
            % The task light is a neutral gray when no protocol is loaded
            ChangeLight(app, app.TaskLight,[.5 .5 .5]);
            
            %****** RE-ENABLE THE SUBJECT ENTRY, in case want to change subject and
            %****** continue the program without closing MarmoV6 (should be rare)
            app.OutputPanel.Visible = 'On';
            app.OutputPrefixEdit.Enable = 'Off';
            app.OutputSubjectEdit.Enable = 'On';   %user can edit this!
            app.OutputDateEdit.Enable = 'Off';
            app.OutputSuffixEdit.Enable = 'Off';
        end

        % Button pushed function: PauseTrial
        function PauseTrialButtonPushed(app, event)
            % Pause button can also act as an unpause button
            if ~app.stopTask
                app.stopTask = true;
                % SET TASK LIGHT TO ORANGE
                ChangeLight(app, app.TaskLight,[.9 .7 .2]);
            end
        end

        % Button pushed function: CloseGui
        function CloseGuiButtonPushed(app, event)
            % Close all screens from ptb
            sca;
            % If Data File Open, condense appended D's into one struct ****
            CondenseAppendedData(app);
            % Close the pump
            app.reward.report()
            delete(app.reward); app.reward = NaN;
        
            % Save any changes to the calibration
            c = app.A.c; %#ok<NASGU>    Supressing editor errors because theses
            dx = app.A.dx; %#ok<NASGU>  variables are being saved
            dy = app.A.dy; %#ok<NASGU>
        %     if ~app.S.DummyEye
        %         save(fullfile(app.supportPath, 'MarmoViewLastCalib.mat'),'c','dx','dy');
        %     end

            Calibfname=[(app.eyetrackername) '_' app.outputSubject '_Calib.mat'];
            save(fullfile(app.supportPath,'Calibrations',Calibfname),'c','dx','dy');
        
            %CLOSE ALL INPUTS AND OUTPUTS
            for i=1:length(app.inputs)
                app.inputs{i}.close;
            end
        
            for i=1:length(app.outputs)
                app.outputs{i}.close;
            end
        

            IOPort('CloseAll')
            % Close the gui window
            close(app.MarmoV6UIFigure);
        end

        % Button pushed function: Calib_Screen
        function Calib_ScreenButtonPushed(app, eventdata)
            % If a bkgd parameter exists, flip frame with background color value
            % Screen('FillRect',app.A.window,uint8(0));
            % Screen('Flip',app.A.window);
            app.runImage = true;
            app.runOneTrial = true; % keep running till paused, or true stop at one
            hold_dir = app.SI.ImageDirectory;
            app.PRI.load_image_dir(['SupportData',filesep,'ForagePoint']);
            %guidata(hObject,handles);
            %RunTrial_Callback(app,eventdata)
            app.RunTrial.ButtonPushedFcn(app, eventdata)
            % it appears if handles changed, you need to regrab it
            % what lives in this function is the old copy of it
            %handles = guidata(hObject);
            %**********
            app.runImage = false;
            app.runOneTrial = false;
            app.PRI.load_image_dir(hold_dir);
        end

        % Button pushed function: CenterEye
        function CenterEyeButtonPushed(app, event)
            [x,y] = app.eyetrack.getgaze();
            app.A.c = [x,y];
            %guidata(hObject,handles);
            UpdateEyeText(app);
            UpdateEyePlot(app);
        end

        % Button pushed function: FlipFrame
        function FlipFrameButtonPushed(app, event)
            % If a bkgd parameter exists, flip frame with background color value
            if isfield(app.P,'bkgd')
                Screen('FillRect',app.A.window,uint8(app.P.bkgd));
            end
            Screen('Flip',app.A.window);
        end

        % Value changed function: ParameterEdit
        function ParameterEditValueChanged(app, event)
            pValue = app.ParameterEdit.Value;

            % Get the new parameter value
            %pValue = str2double(get(hObject,'String'));
            % Get the parameter name
            pName = app.pNames{get(app.Parameters,'Value')};
            % If the parameter value is a number
            if ~isnan(pValue)
                % Change the parameter value
                app.P.(pName) = str2double(pValue);
                % Update the parameter list immediately if not in the run loop
                if ~app.runTask
                    tName = sprintf('%s = %2g',pName,app.P.(pName));
                    app.pList{get(app.Parameters,'Value')} = tName;
                    set(app.Parameters,'Items',app.pList);
                end
        
            else
                % Revert the parameter text to the previous value
                set(app.Parameters,'Items',num2str(app.P.(pName)));
            end
        end

        % Value changed function: Parameters
        function ParametersValueChanged(app, event)

            %No longer an index, app.Parameters.Value just spits out the
            %ItemsData contents for that selection. Changed itemsdata to
            %index so this still works
            value=app.Parameters.Value;
            if isscalar(value)
                i = value;
            else
                find(app.P==value)
            end

            % Set the parameter text to a description of the parameter
            set(app.ParameterText,'Text',app.S.(app.pNames{i}));
            % Set the parameter edit to the current value of that parameter
            set(app.ParameterEdit,'Value',num2str(app.P.(app.pNames{i})));
            % Update handles structure
            %guidata(hObject,handles);
        end

        % Button pushed function: GiveJuice
        function GiveJuiceButtonPushed(app, event)
                app.reward.deliver();
                app.A.juiceCounter = app.A.juiceCounter + 1;
        end

        % Value changed function: JuiceVolumeEdit
        function JuiceVolumeEditValueChanged(app, event)
            vol=app.JuiceVolumeEdit.Value;
            volUL = str2double(vol); % microliters
        
            % fprintf(app.A.pump,['0 VOL ' volML]);
            app.reward.volume = volUL; % milliliters
            if app.S.solenoid
                %set(app.JuiceVolumeText.Text,'String',[vol ' ms']); % displayed in microliters!!
                app.JuiceVolumeText.Text=[vol ' ms'];
            else
                %set(app.JuiceVolumeText.Text,'String',[vol ' ul']);
                app.JuiceVolumeText.Text=[vol ' ul'];
            end
            %set(hObject,'String',''); % why?
            app.A.juiceVolume = volUL; % <-- A.juiceVolume should *always* be in milliliters!
            
        end

        % Button pushed function: GainDownX
        function GainDownXButtonPushed(app, event)
            app.A.dx = (1+app.gainSize)*app.A.dx;
            UpdateEyeText(app);
            UpdateEyePlot(app);
        end

        % Button pushed function: GainUpX
        function GainUpXButtonPushed(app, event)
            % Note we divide by dx, so reducing dx increases gain
            app.A.dx = (1-app.gainSize)*app.A.dx;
            UpdateEyeText(app);
            UpdateEyePlot(app);
        end

        % Button pushed function: GainDownY
        function GainDownYButtonPushed(app, event)
            app.A.dy = (1+app.gainSize)*app.A.dy;
            UpdateEyeText(app);
            UpdateEyePlot(app);
        end

        % Button pushed function: GainUpY
        function GainUpYButtonPushed(app, event)
            app.A.dy = (1-app.gainSize)*app.A.dy;
            UpdateEyeText(app);
            UpdateEyePlot(app);
        end

        % Value changed function: GainSize
        function GainSizeValueChanged(app, event)
            value = str2double(app.GainSize.Value);
            if ~isnan(value)
                app.gainSize = value;
            else
                set(app.GainSize,'String',num2str(app.gainSize));
            end
        end

        % Button pushed function: GraphZoomIn
        function GraphZoomInButtonPushed(app, event)
                % hObject    handle to GraphZoomIn (see GCBO)
                % eventdata  reserved - to be defined in a future version of MATLAB
                % handles    structure with handles and user data (see GUIDATA)
                if app.eyeTraceRadius > 2.5
                    app.eyeTraceRadius = app.eyeTraceRadius-2.5;
                end
                %guidata(hObject,handles);
                UpdateEyePlot(app);            
        end

        % Button pushed function: GraphZoomOut
        function GraphZoomOutButtonPushed(app, event)
                % hObject    handle to GraphZoomOut (see GCBO)
                % eventdata  reserved - to be defined in a future version of MATLAB
                % handles    structure with handles and user data (see GUIDATA)
                if app.eyeTraceRadius < 30
                    app.eyeTraceRadius = app.eyeTraceRadius+2.5;
                end
                %guidata(hObject,handles);
                UpdateEyePlot(app);            
        end

        % Value changed function: OutputDateEdit
        function OutputDateEditValueChanged(app, event)
            app.outputDate = app.OutputDateEdit.Value;
            UpdateOutputFilename(app);
            %guidata(hObject,handles);            
        end

        % Value changed function: OutputSuffixEdit
        function OutputSuffixEditValueChanged(app, event)
            app.outputSuffix = app.OutputSuffixEdit.Value;
            UpdateOutputFilename(app);           
        end

        % Value changed function: OutputPrefixEdit
        function OutputPrefixEditValueChanged(app, event)
            app.outputPrefix = app.OutputPrefixEdit.Value;
            UpdateOutputFilename(app);           
        end

        % Button pushed function: Refresh_Trials
        function Refresh_TrialsButtonPushed(app, event)
            %REBUILD A NEW TRIALS LIST FROM CURRENT PARAMS
            app.PR.generate_trialsList(app.S,app.P);
            % DE-INITIALIZE OBJECTS (may need to make new if Param changed)
            app.PR.closeFunc();
            % RE-INITIALIZE OBJECTS (may need to make new if Param changed)
            app.PR.initFunc(app.S,app.P);
        end

        % Button pushed function: ResetCalibration
        function ResetCalibrationButtonPushed(app, event)
            app.A.dx = app.C.dx;
            app.A.dy = app.C.dy;
            app.A.c = app.C.c;
            %guidata(hObject,handles);
            UpdateEyeText(app);
            UpdateEyePlot(app);
        end

        % Button pushed function: ShiftRight
        function ShiftRightButtonPushed(app, event)
            app.A.c(1) = app.A.c(1) - ...
                app.shiftSize*app.A.dx*app.S.pixPerDeg;
            %guidata(hObject);
            %app.A.c(1)
            UpdateEyeText(app);
            UpdateEyePlot(app);            
        end

        % Button pushed function: ShiftLeft
        function ShiftLeftButtonPushed(app, event)
            app.A.c(1) = app.A.c(1) + ...
                app.shiftSize*app.A.dx*app.S.pixPerDeg;
            %guidata(hObject);
            UpdateEyeText(app);
            UpdateEyePlot(app);
        end

        % Button pushed function: ShiftDown
        function ShiftDownButtonPushed(app, event)
            app.A.c(2) = app.A.c(2) + ...
                app.shiftSize*app.A.dy*app.S.pixPerDeg;
            %guidata(hObject);
            UpdateEyeText(app);
            UpdateEyePlot(app);
        end

        % Button pushed function: ShiftUp
        function ShiftUpButtonPushed(app, event)
            app.A.c(2) = app.A.c(2) - ...
                app.shiftSize*app.A.dy*app.S.pixPerDeg;
            %guidata(hObject);
            UpdateEyeText(app);
            UpdateEyePlot(app);            
        end

        % Value changed function: ShiftSize
        function ShiftSizeValueChanged(app, event)
            value = app.ShiftSize.Value;
            shiftSize = str2double(value);
            if ~isnan(shiftSize)
                app.shiftSize = shiftSize;
                guidata(hObject);
            else
                set(app.ShiftSize,'String',num2str(app.shiftSize));
            end
        end

        % Value changed function: slider_P4intensity
        function slider_P4intensityValueChanged(app, event)
            value = app.slider_P4intensity.Value;
            if isa(app.eyetrack, 'marmoview.eyetrack_ddpi')
                app.eyetrack.p4intensity = value;
                ddpiM('setP4Template', [app.eyetrack.p4intensity, app.eyetrack.p4radius]);
                fprintf('Setting P4 intensity to: %f\n',  app.eyetrack.p4intensity)
            end
        end

        % Value changed function: slider_P4radius
        function slider_P4radiusValueChanged(app, event)
            value = app.slider_P4radius.Value;
            if isa(app.eyetrack, 'marmoview.eyetrack_ddpi')
                app.eyetrack.p4radius = value;
                ddpiM('setP4Template', [app.eyetrack.p4intensity, app.eyetrack.p4radius]);
                fprintf('Setting P4 radius to: %f\n',  app.eyetrack.p4radius)
            end
        end

        % Button pushed function: ResetGUI
        function ResetGUIButtonPushed(app, event)
            % Close all screens from ptb
            sca;
            % If Data File Open, condense appended D's into one struct ****
            CondenseAppendedData(app);
            % Close the pump
            app.reward.report()
            delete(app.reward); app.reward = NaN;
        
            % Save any changes to the calibration
            c = app.A.c; %#ok<NASGU>    Supressing editor errors because theses
            dx = app.A.dx; %#ok<NASGU>  variables are being saved
            dy = app.A.dy; %#ok<NASGU>

            Calibfname=[(app.eyetrackername) '_' app.outputSubject '_Calib.mat'];
            save(fullfile(app.supportPath,'Calibrations',Calibfname),'c','dx','dy');
        
            %CLOSE ALL INPUTS AND OUTPUTS
            for i=1:length(app.inputs)
                app.inputs{i}.close;
            end
        
            for i=1:length(app.outputs)
                app.outputs{i}.close;
            end
        
            IOPort('CloseAll')
            % Restart the gui window
            app.OutputSubjectEdit.Enable= "on";
            app.ChooseSettings.Enable= "on";
            startupFcn(app)
        end

        % Value changed function: TrialMaxEdit
        function TrialMaxEditValueChanged(app, event)
            value = app.TrialMaxEdit.Value;

            % Get the new count
            newFinal = round(str2double(value));
            % Make sure the new final trial is a positive integer
            if newFinal > 0
                % Update the final trial
                app.A.finish = newFinal;
                % Set the count
                app.TrialMaxText.Text=num2str(value);
            end
            % Clear the edit string
            app.TrialMaxEdit.Value='';
            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create MarmoV6UIFigure and hide until all components are created
            app.MarmoV6UIFigure = uifigure('Visible', 'off');
            app.MarmoV6UIFigure.Position = [100 100 914 670];
            app.MarmoV6UIFigure.Name = 'MarmoV6';

            % Create Title
            app.Title = uilabel(app.MarmoV6UIFigure);
            app.Title.Tag = 'Title';
            app.Title.VerticalAlignment = 'top';
            app.Title.WordWrap = 'on';
            app.Title.FontSize = 18.6666666666667;
            app.Title.FontWeight = 'bold';
            app.Title.Position = [26 629 200 28];
            app.Title.Text = 'MarmoView  v.6';

            % Create ControlsPanel
            app.ControlsPanel = uibuttongroup(app.MarmoV6UIFigure);
            app.ControlsPanel.ForegroundColor = [0.203921568627451 0.301960784313725 0.494117647058824];
            app.ControlsPanel.Title = 'Trial Control';
            app.ControlsPanel.Tag = 'ControlsPanel';
            app.ControlsPanel.FontWeight = 'bold';
            app.ControlsPanel.FontSize = 16;
            app.ControlsPanel.Position = [26 387 265 90];

            % Create TaskLight
            app.TaskLight = uiaxes(app.ControlsPanel);
            app.TaskLight.FontSize = 10.6666666666667;
            app.TaskLight.NextPlot = 'replace';
            app.TaskLight.Tag = 'TaskLight';
            app.TaskLight.Position = [-4 7 59 62];

            % Create RunTrial
            app.RunTrial = uibutton(app.ControlsPanel, 'push');
            app.RunTrial.ButtonPushedFcn = createCallbackFcn(app, @RunTrialButtonPushed, true);
            app.RunTrial.Tag = 'RunTrial';
            app.RunTrial.FontSize = 13.3333333333333;
            app.RunTrial.Position = [54 39 70 24];
            app.RunTrial.Text = 'Run';

            % Create PauseTrial
            app.PauseTrial = uibutton(app.ControlsPanel, 'push');
            app.PauseTrial.ButtonPushedFcn = createCallbackFcn(app, @PauseTrialButtonPushed, true);
            app.PauseTrial.Tag = 'PauseTrial';
            app.PauseTrial.FontSize = 13.3333333333333;
            app.PauseTrial.Position = [54 11 70 24];
            app.PauseTrial.Text = 'Pause';

            % Create GiveJuice
            app.GiveJuice = uibutton(app.ControlsPanel, 'push');
            app.GiveJuice.ButtonPushedFcn = createCallbackFcn(app, @GiveJuiceButtonPushed, true);
            app.GiveJuice.Tag = 'GiveJuice';
            app.GiveJuice.FontSize = 13.3333333333333;
            app.GiveJuice.Position = [132 39 70 24];
            app.GiveJuice.Text = 'Juice';

            % Create JuiceVolumeEdit
            app.JuiceVolumeEdit = uieditfield(app.ControlsPanel, 'text');
            app.JuiceVolumeEdit.ValueChangedFcn = createCallbackFcn(app, @JuiceVolumeEditValueChanged, true);
            app.JuiceVolumeEdit.Tag = 'JuiceVolumeEdit';
            app.JuiceVolumeEdit.HorizontalAlignment = 'center';
            app.JuiceVolumeEdit.FontSize = 13.3333333333333;
            app.JuiceVolumeEdit.Position = [211 41 41 22];

            % Create JuiceVolumeText
            app.JuiceVolumeText = uilabel(app.ControlsPanel);
            app.JuiceVolumeText.Tag = 'JuiceVolumeText';
            app.JuiceVolumeText.HorizontalAlignment = 'center';
            app.JuiceVolumeText.VerticalAlignment = 'top';
            app.JuiceVolumeText.WordWrap = 'on';
            app.JuiceVolumeText.FontSize = 13.3333333333333;
            app.JuiceVolumeText.Position = [206 18 52 18];
            app.JuiceVolumeText.Text = '10 ul';

            % Create FlipFrame
            app.FlipFrame = uibutton(app.ControlsPanel, 'push');
            app.FlipFrame.ButtonPushedFcn = createCallbackFcn(app, @FlipFrameButtonPushed, true);
            app.FlipFrame.Tag = 'FlipFrame';
            app.FlipFrame.FontSize = 13.3333333333333;
            app.FlipFrame.Position = [132 11 70 24];
            app.FlipFrame.Text = 'Flip Frame';

            % Create CloseGui
            app.CloseGui = uibutton(app.MarmoV6UIFigure, 'push');
            app.CloseGui.ButtonPushedFcn = createCallbackFcn(app, @CloseGuiButtonPushed, true);
            app.CloseGui.Tag = 'CloseGui';
            app.CloseGui.FontSize = 18.6666666666667;
            app.CloseGui.Position = [701 632 200 29];
            app.CloseGui.Text = {'Close MarmoView'; 'GUI'};

            % Create ProtocolTitle
            app.ProtocolTitle = uilabel(app.MarmoV6UIFigure);
            app.ProtocolTitle.Tag = 'ProtocolTitle';
            app.ProtocolTitle.VerticalAlignment = 'top';
            app.ProtocolTitle.WordWrap = 'on';
            app.ProtocolTitle.FontSize = 16;
            app.ProtocolTitle.FontWeight = 'bold';
            app.ProtocolTitle.FontColor = [0.203921568627451 0.301960784313725 0.494117647058824];
            app.ProtocolTitle.Position = [26 602 265 22];
            app.ProtocolTitle.Text = 'Protocol Title';

            % Create SettingsPanel
            app.SettingsPanel = uipanel(app.MarmoV6UIFigure);
            app.SettingsPanel.ForegroundColor = [0.203921568627451 0.301960784313725 0.494117647058824];
            app.SettingsPanel.Title = 'Settings File';
            app.SettingsPanel.Visible = 'off';
            app.SettingsPanel.Tag = 'SettingsPanel';
            app.SettingsPanel.FontWeight = 'bold';
            app.SettingsPanel.FontSize = 16;
            app.SettingsPanel.Position = [26 492 265 84];

            % Create ChooseSettings
            app.ChooseSettings = uibutton(app.SettingsPanel, 'push');
            app.ChooseSettings.ButtonPushedFcn = createCallbackFcn(app, @ChooseSettingsButtonPushed, true);
            app.ChooseSettings.Tag = 'ChooseSettings';
            app.ChooseSettings.FontSize = 13.3333333333333;
            app.ChooseSettings.Position = [5 5 75 24];
            app.ChooseSettings.Text = 'Browse';

            % Create Initialize
            app.Initialize = uibutton(app.SettingsPanel, 'push');
            app.Initialize.ButtonPushedFcn = createCallbackFcn(app, @InitializeButtonPushed, true);
            app.Initialize.Tag = 'Initialize';
            app.Initialize.FontSize = 13.3333333333333;
            app.Initialize.Position = [84 5 75 24];
            app.Initialize.Text = 'Initialize';

            % Create ClearSettings
            app.ClearSettings = uibutton(app.SettingsPanel, 'push');
            app.ClearSettings.ButtonPushedFcn = createCallbackFcn(app, @ClearSettingsButtonPushed, true);
            app.ClearSettings.Tag = 'ClearSettings';
            app.ClearSettings.FontSize = 13.3333333333333;
            app.ClearSettings.Position = [163 5 96 24];
            app.ClearSettings.Text = 'Save & Clear';

            % Create SettingsFile
            app.SettingsFile = uilabel(app.SettingsPanel);
            app.SettingsFile.Tag = 'SettingsFile';
            app.SettingsFile.VerticalAlignment = 'top';
            app.SettingsFile.WordWrap = 'on';
            app.SettingsFile.FontSize = 13.3333333333333;
            app.SettingsFile.Position = [10 36 232 18];
            app.SettingsFile.Text = 'SettingsFile.m';

            % Create Calib_Screen
            app.Calib_Screen = uibutton(app.SettingsPanel, 'push');
            app.Calib_Screen.ButtonPushedFcn = createCallbackFcn(app, @Calib_ScreenButtonPushed, true);
            app.Calib_Screen.Tag = 'Calib_Screen';
            app.Calib_Screen.FontSize = 10.6666666666667;
            app.Calib_Screen.Position = [140 35 40.8333333333333 23.2142857142857];
            app.Calib_Screen.Text = 'Calib';

            % Create Background_Image
            app.Background_Image = uibutton(app.SettingsPanel, 'push');
            app.Background_Image.ButtonPushedFcn = createCallbackFcn(app, @Background_ImageButtonPushed, true);
            app.Background_Image.Tag = 'Background_Image';
            app.Background_Image.FontSize = 10.6666666666667;
            app.Background_Image.Position = [188 35 69.1666666666667 23.2142857142857];
            app.Background_Image.Text = 'Backgrnd';

            % Create EyeTrackerPanel
            app.EyeTrackerPanel = uipanel(app.MarmoV6UIFigure);
            app.EyeTrackerPanel.ForegroundColor = [0.203921568627451 0.301960784313725 0.494117647058824];
            app.EyeTrackerPanel.Title = 'Eye Tracker Control';
            app.EyeTrackerPanel.Visible = 'off';
            app.EyeTrackerPanel.Tag = 'EyeTrackerPanel';
            app.EyeTrackerPanel.FontWeight = 'bold';
            app.EyeTrackerPanel.FontSize = 16;
            app.EyeTrackerPanel.Position = [301 17 310 490];

            % Create EyeTrace
            app.EyeTrace = uiaxes(app.EyeTrackerPanel);
            app.EyeTrace.XLim = [-15 15];
            app.EyeTrace.YLim = [-15 15];
            app.EyeTrace.XDir = 'reverse'; 
            app.EyeTrace.YDir ="reverse";
            app.EyeTrace.FontSize = 12;
            app.EyeTrace.NextPlot = 'replace';
            app.EyeTrace.BusyAction = 'cancel';
            app.EyeTrace.Tag = 'EyeTrace';
            app.EyeTrace.Position = [28 230 242 208];

            % Create ShiftRight
            app.ShiftRight = uibutton(app.EyeTrackerPanel, 'push');
            app.ShiftRight.ButtonPushedFcn = createCallbackFcn(app, @ShiftRightButtonPushed, true);
            app.ShiftRight.Tag = 'ShiftRight';
            app.ShiftRight.FontSize = 18.6666666666667;
            app.ShiftRight.Position = [107 124 34 34];
            app.ShiftRight.Text = 'R';

            % Create ShiftLeft
            app.ShiftLeft = uibutton(app.EyeTrackerPanel, 'push');
            app.ShiftLeft.ButtonPushedFcn = createCallbackFcn(app, @ShiftLeftButtonPushed, true);
            app.ShiftLeft.Tag = 'ShiftLeft';
            app.ShiftLeft.FontSize = 18.6666666666667;
            app.ShiftLeft.Position = [36 125 34 34];
            app.ShiftLeft.Text = 'L';

            % Create ShiftDown
            app.ShiftDown = uibutton(app.EyeTrackerPanel, 'push');
            app.ShiftDown.ButtonPushedFcn = createCallbackFcn(app, @ShiftDownButtonPushed, true);
            app.ShiftDown.Tag = 'ShiftDown';
            app.ShiftDown.FontSize = 18.6666666666667;
            app.ShiftDown.Position = [72 87 34 34];
            app.ShiftDown.Text = 'D';

            % Create ShiftUp
            app.ShiftUp = uibutton(app.EyeTrackerPanel, 'push');
            app.ShiftUp.ButtonPushedFcn = createCallbackFcn(app, @ShiftUpButtonPushed, true);
            app.ShiftUp.Tag = 'ShiftUp';
            app.ShiftUp.FontSize = 18.6666666666667;
            app.ShiftUp.Position = [72 159 34 34];
            app.ShiftUp.Text = 'U';

            % Create ShiftSize
            app.ShiftSize = uieditfield(app.EyeTrackerPanel, 'text');
            app.ShiftSize.ValueChangedFcn = createCallbackFcn(app, @ShiftSizeValueChanged, true);
            app.ShiftSize.Tag = 'ShiftSize';
            app.ShiftSize.HorizontalAlignment = 'center';
            app.ShiftSize.FontSize = 10.6666666666667;
            app.ShiftSize.Position = [73 126 32 30];
            app.ShiftSize.Value = '.2';

            % Create text2
            app.text2 = uilabel(app.EyeTrackerPanel);
            app.text2.Tag = 'text2';
            app.text2.HorizontalAlignment = 'center';
            app.text2.VerticalAlignment = 'top';
            app.text2.WordWrap = 'on';
            app.text2.FontSize = 13.3333333333333;
            app.text2.Position = [24 209 98 18];
            app.text2.Text = 'Shift Eye Center';

            % Create text7
            app.text7 = uilabel(app.EyeTrackerPanel);
            app.text7.Tag = 'text7';
            app.text7.HorizontalAlignment = 'center';
            app.text7.VerticalAlignment = 'top';
            app.text7.WordWrap = 'on';
            app.text7.FontSize = 13.3333333333333;
            app.text7.Position = [183 210 111 18];
            app.text7.Text = 'Change Eye Gain';

            % Create GainUpX
            app.GainUpX = uibutton(app.EyeTrackerPanel, 'push');
            app.GainUpX.ButtonPushedFcn = createCallbackFcn(app, @GainUpXButtonPushed, true);
            app.GainUpX.Tag = 'GainUpX';
            app.GainUpX.FontSize = 18.6666666666667;
            app.GainUpX.Position = [239 123 34 34];
            app.GainUpX.Text = '+';

            % Create GainDownX
            app.GainDownX = uibutton(app.EyeTrackerPanel, 'push');
            app.GainDownX.ButtonPushedFcn = createCallbackFcn(app, @GainDownXButtonPushed, true);
            app.GainDownX.Tag = 'GainDownX';
            app.GainDownX.FontSize = 18.6666666666667;
            app.GainDownX.Position = [168 125 34 34];
            app.GainDownX.Text = '-';

            % Create GainDownY
            app.GainDownY = uibutton(app.EyeTrackerPanel, 'push');
            app.GainDownY.ButtonPushedFcn = createCallbackFcn(app, @GainDownYButtonPushed, true);
            app.GainDownY.Tag = 'GainDownY';
            app.GainDownY.FontSize = 18.6666666666667;
            app.GainDownY.Position = [204 87 34 34];
            app.GainDownY.Text = '-';

            % Create GainUpY
            app.GainUpY = uibutton(app.EyeTrackerPanel, 'push');
            app.GainUpY.ButtonPushedFcn = createCallbackFcn(app, @GainUpYButtonPushed, true);
            app.GainUpY.Tag = 'GainUpY';
            app.GainUpY.FontSize = 18.6666666666667;
            app.GainUpY.Position = [204 159 34 34];
            app.GainUpY.Text = '+';

            % Create GainSize
            app.GainSize = uieditfield(app.EyeTrackerPanel, 'text');
            app.GainSize.ValueChangedFcn = createCallbackFcn(app, @GainSizeValueChanged, true);
            app.GainSize.Tag = 'GainSize';
            app.GainSize.HorizontalAlignment = 'center';
            app.GainSize.FontSize = 10.6666666666667;
            app.GainSize.Position = [205 126 32 30];
            app.GainSize.Value = '.05';

            % Create CalibFilename
            app.CalibFilename = uilabel(app.EyeTrackerPanel);
            app.CalibFilename.Tag = 'CalibFilename';
            app.CalibFilename.HorizontalAlignment = 'right';
            app.CalibFilename.VerticalAlignment = 'top';
            app.CalibFilename.WordWrap = 'on';
            app.CalibFilename.FontSize = 13.3333333333333;
            app.CalibFilename.Position = [41 8 193 17];
            app.CalibFilename.Text = 'CalibFilename';

            % Create CenterEye
            app.CenterEye = uibutton(app.EyeTrackerPanel, 'push');
            app.CenterEye.ButtonPushedFcn = createCallbackFcn(app, @CenterEyeButtonPushed, true);
            app.CenterEye.Tag = 'CenterEye';
            app.CenterEye.FontSize = 16;
            app.CenterEye.Position = [120 177 73 27];
            app.CenterEye.Text = 'Center';

            % Create CenterText
            app.CenterText = uilabel(app.EyeTrackerPanel);
            app.CenterText.Tag = 'CenterText';
            app.CenterText.HorizontalAlignment = 'center';
            app.CenterText.VerticalAlignment = 'top';
            app.CenterText.WordWrap = 'on';
            app.CenterText.FontSize = 10.6666666666667;
            app.CenterText.Position = [107 102 78 15];
            app.CenterText.Text = '[cx, cy]';

            % Create GainText
            app.GainText = uilabel(app.EyeTrackerPanel);
            app.GainText.Tag = 'GainText';
            app.GainText.HorizontalAlignment = 'center';
            app.GainText.VerticalAlignment = 'top';
            app.GainText.WordWrap = 'on';
            app.GainText.FontSize = 10.6666666666667;
            app.GainText.Position = [107 88 78 14];
            app.GainText.Text = '[dx, dy]';

            % Create ResetCalibration
            app.ResetCalibration = uibutton(app.EyeTrackerPanel, 'push');
            app.ResetCalibration.ButtonPushedFcn = createCallbackFcn(app, @ResetCalibrationButtonPushed, true);
            app.ResetCalibration.Tag = 'ResetCalibration';
            app.ResetCalibration.FontSize = 13.3333333333333;
            app.ResetCalibration.Position = [247 4 52 25];
            app.ResetCalibration.Text = 'Reset';

            % Create text29
            app.text29 = uilabel(app.EyeTrackerPanel);
            app.text29.Tag = 'text29';
            app.text29.HorizontalAlignment = 'center';
            app.text29.VerticalAlignment = 'top';
            app.text29.WordWrap = 'on';
            app.text29.FontSize = 13.3333333333333;
            app.text29.Position = [110 437 90 21.6666666666666];
            app.text29.Text = 'Graph Zoom';

            % Create GraphZoomIn
            app.GraphZoomIn = uibutton(app.EyeTrackerPanel, 'push');
            app.GraphZoomIn.ButtonPushedFcn = createCallbackFcn(app, @GraphZoomInButtonPushed, true);
            app.GraphZoomIn.Tag = 'GraphZoomIn';
            app.GraphZoomIn.FontSize = 13.3333333333333;
            app.GraphZoomIn.Position = [203 434 50.8333333333333 26];
            app.GraphZoomIn.Text = 'in';

            % Create GraphZoomOut
            app.GraphZoomOut = uibutton(app.EyeTrackerPanel, 'push');
            app.GraphZoomOut.ButtonPushedFcn = createCallbackFcn(app, @GraphZoomOutButtonPushed, true);
            app.GraphZoomOut.Tag = 'GraphZoomOut';
            app.GraphZoomOut.FontSize = 13.3333333333333;
            app.GraphZoomOut.Position = [60 434 45 26];
            app.GraphZoomOut.Text = 'out';

            % Create text30
            app.text30 = uilabel(app.EyeTrackerPanel);
            app.text30.Tag = 'text30';
            app.text30.HorizontalAlignment = 'center';
            app.text30.VerticalAlignment = 'top';
            app.text30.WordWrap = 'on';
            app.text30.FontSize = 13.3333333333333;
            app.text30.Position = [4 60 72.5 16.7142857142857];
            app.text30.Text = 'P4 intensity';

            % Create slider_P4intensity
            app.slider_P4intensity = uislider(app.EyeTrackerPanel);
            app.slider_P4intensity.Limits = [1 255];
            app.slider_P4intensity.MajorTicks = [];
            app.slider_P4intensity.ValueChangedFcn = createCallbackFcn(app, @slider_P4intensityValueChanged, true);
            app.slider_P4intensity.MinorTicks = [];
            app.slider_P4intensity.Tag = 'slider_P4intensity';
            app.slider_P4intensity.FontSize = 13.3333333333333;
            app.slider_P4intensity.Position = [80 60 152.5 3];
            app.slider_P4intensity.Value = 200;

            % Create slider_P4radius
            app.slider_P4radius = uislider(app.EyeTrackerPanel);
            app.slider_P4radius.Limits = [0.1 7];
            app.slider_P4radius.MajorTicks = [];
            app.slider_P4radius.ValueChangedFcn = createCallbackFcn(app, @slider_P4radiusValueChanged, true);
            app.slider_P4radius.MinorTicks = [];
            app.slider_P4radius.Tag = 'slider_P4radius';
            app.slider_P4radius.FontSize = 13.3333333333333;
            app.slider_P4radius.Position = [79 31 152.5 3];
            app.slider_P4radius.Value = 0.3;

            % Create text31
            app.text31 = uilabel(app.EyeTrackerPanel);
            app.text31.Tag = 'text31';
            app.text31.HorizontalAlignment = 'center';
            app.text31.VerticalAlignment = 'top';
            app.text31.WordWrap = 'on';
            app.text31.FontSize = 13.3333333333333;
            app.text31.Position = [4 30 60 16.7142857142857];
            app.text31.Text = 'P4 radius';

            % Create OutputPanel
            app.OutputPanel = uipanel(app.MarmoV6UIFigure);
            app.OutputPanel.ForegroundColor = [0.203921568627451 0.301960784313725 0.494117647058824];
            app.OutputPanel.Title = 'Output File';
            app.OutputPanel.Tag = 'OutputPanel';
            app.OutputPanel.FontWeight = 'bold';
            app.OutputPanel.FontSize = 16;
            app.OutputPanel.Position = [301 517 310 112];

            % Create OutputPrefixEdit
            app.OutputPrefixEdit = uieditfield(app.OutputPanel, 'text');
            app.OutputPrefixEdit.ValueChangedFcn = createCallbackFcn(app, @OutputPrefixEditValueChanged, true);
            app.OutputPrefixEdit.Tag = 'OutputPrefixEdit';
            app.OutputPrefixEdit.HorizontalAlignment = 'center';
            app.OutputPrefixEdit.FontSize = 13.3333333333333;
            app.OutputPrefixEdit.Position = [66 42 80 22];

            % Create OutputSubjectEdit
            app.OutputSubjectEdit = uieditfield(app.OutputPanel, 'text');
            app.OutputSubjectEdit.ValueChangedFcn = createCallbackFcn(app, @OutputSubjectEditValueChanged, true);
            app.OutputSubjectEdit.Tag = 'OutputSubjectEdit';
            app.OutputSubjectEdit.HorizontalAlignment = 'center';
            app.OutputSubjectEdit.FontSize = 13.3333333333333;
            app.OutputSubjectEdit.Position = [66 16 80 22];

            % Create OutputDateEdit
            app.OutputDateEdit = uieditfield(app.OutputPanel, 'text');
            app.OutputDateEdit.ValueChangedFcn = createCallbackFcn(app, @OutputDateEditValueChanged, true);
            app.OutputDateEdit.Tag = 'OutputDateEdit';
            app.OutputDateEdit.HorizontalAlignment = 'center';
            app.OutputDateEdit.FontSize = 13.3333333333333;
            app.OutputDateEdit.Position = [205 40 80 24];

            % Create OutputSuffixEdit
            app.OutputSuffixEdit = uieditfield(app.OutputPanel, 'text');
            app.OutputSuffixEdit.ValueChangedFcn = createCallbackFcn(app, @OutputSuffixEditValueChanged, true);
            app.OutputSuffixEdit.Tag = 'OutputSuffixEdit';
            app.OutputSuffixEdit.HorizontalAlignment = 'center';
            app.OutputSuffixEdit.FontSize = 13.3333333333333;
            app.OutputSuffixEdit.Position = [205 16 80 22];

            % Create OutputPrefixLabel
            app.OutputPrefixLabel = uilabel(app.OutputPanel);
            app.OutputPrefixLabel.Tag = 'OutputPrefixLabel';
            app.OutputPrefixLabel.HorizontalAlignment = 'right';
            app.OutputPrefixLabel.VerticalAlignment = 'top';
            app.OutputPrefixLabel.WordWrap = 'on';
            app.OutputPrefixLabel.FontSize = 13.3333333333333;
            app.OutputPrefixLabel.Position = [12 43 52 18];
            app.OutputPrefixLabel.Text = 'Prefix:';

            % Create OutputSubjectLabel
            app.OutputSubjectLabel = uilabel(app.OutputPanel);
            app.OutputSubjectLabel.Tag = 'OutputSubjectLabel';
            app.OutputSubjectLabel.HorizontalAlignment = 'right';
            app.OutputSubjectLabel.VerticalAlignment = 'top';
            app.OutputSubjectLabel.WordWrap = 'on';
            app.OutputSubjectLabel.FontSize = 13.3333333333333;
            app.OutputSubjectLabel.Position = [12 17 52 18];
            app.OutputSubjectLabel.Text = 'Subject:';

            % Create OutputDateLabel
            app.OutputDateLabel = uilabel(app.OutputPanel);
            app.OutputDateLabel.Tag = 'OutputDateLabel';
            app.OutputDateLabel.HorizontalAlignment = 'right';
            app.OutputDateLabel.VerticalAlignment = 'top';
            app.OutputDateLabel.WordWrap = 'on';
            app.OutputDateLabel.FontSize = 13.3333333333333;
            app.OutputDateLabel.Position = [163 42 39 18];
            app.OutputDateLabel.Text = 'Date:';

            % Create OutputSuffixLabel
            app.OutputSuffixLabel = uilabel(app.OutputPanel);
            app.OutputSuffixLabel.Tag = 'OutputSuffixLabel';
            app.OutputSuffixLabel.HorizontalAlignment = 'right';
            app.OutputSuffixLabel.VerticalAlignment = 'top';
            app.OutputSuffixLabel.WordWrap = 'on';
            app.OutputSuffixLabel.FontSize = 13.3333333333333;
            app.OutputSuffixLabel.Position = [163 17 39 18];
            app.OutputSuffixLabel.Text = 'Suffix:';

            % Create OutputFile
            app.OutputFile = uilabel(app.OutputPanel);
            app.OutputFile.Tag = 'OutputFile';
            app.OutputFile.VerticalAlignment = 'top';
            app.OutputFile.WordWrap = 'on';
            app.OutputFile.FontSize = 13.3333333333333;
            app.OutputFile.Position = [10 69 284 18];
            app.OutputFile.Text = 'OutputFile.mat';

            % Create TaskPerformancePanel
            app.TaskPerformancePanel = uipanel(app.MarmoV6UIFigure);
            app.TaskPerformancePanel.ForegroundColor = [0.203921568627451 0.301960784313725 0.494117647058824];
            app.TaskPerformancePanel.Title = 'Task Performance';
            app.TaskPerformancePanel.Visible = 'off';
            app.TaskPerformancePanel.Tag = 'TaskPerformancePanel';
            app.TaskPerformancePanel.FontWeight = 'bold';
            app.TaskPerformancePanel.FontSize = 16;
            app.TaskPerformancePanel.Position = [621 17 280 612];

            % Create DataPlot1
            app.DataPlot1 = uiaxes(app.TaskPerformancePanel);
            app.DataPlot1.FontSize = 10.6666666666667;
            app.DataPlot1.NextPlot = 'replace';
            app.DataPlot1.Tag = 'DataPlot1';
            app.DataPlot1.Position = [36 433 226 69];

            % Create DataPlot2
            app.DataPlot2 = uiaxes(app.TaskPerformancePanel);
            app.DataPlot2.FontSize = 12;
            app.DataPlot2.NextPlot = 'replace';
            app.DataPlot2.Tag = 'DataPlot2';
            app.DataPlot2.Position = [36 238 224 191];

            % Create DataPlot3
            app.DataPlot3 = uiaxes(app.TaskPerformancePanel);
            app.DataPlot3.FontSize = 12;
            app.DataPlot3.NextPlot = 'replace';
            app.DataPlot3.Tag = 'DataPlot3';
            app.DataPlot3.Position = [36 67 227 191];

            % Create DataPlot4
            app.DataPlot4 = uiaxes(app.TaskPerformancePanel);
            app.DataPlot4.FontSize = 10.6666666666667;
            app.DataPlot4.NextPlot = 'replace';
            app.DataPlot4.Tag = 'DataPlot4';
            app.DataPlot4.Position = [44 511 191 61];

            % Create StatusText
            app.StatusText = uilabel(app.MarmoV6UIFigure);
            app.StatusText.Tag = 'StatusText';
            app.StatusText.VerticalAlignment = 'top';
            app.StatusText.WordWrap = 'on';
            app.StatusText.FontSize = 16;
            app.StatusText.FontWeight = 'bold';
            app.StatusText.FontColor = [0.203921568627451 0.301960784313725 0.494117647058824];
            app.StatusText.Position = [26 575 265 22];
            app.StatusText.Text = 'Protocol Status';

            % Create AuthorText
            app.AuthorText = uilabel(app.MarmoV6UIFigure);
            app.AuthorText.Tag = 'AuthorText';
            app.AuthorText.VerticalAlignment = 'top';
            app.AuthorText.WordWrap = 'on';
            app.AuthorText.FontSize = 10.6666666666667;
            app.AuthorText.FontWeight = 'bold';
            app.AuthorText.FontAngle = 'italic';
            app.AuthorText.Position = [311 633 190 21];
            app.AuthorText.Text = 'marmolab@bcs.rochester.edu';

            % Create ParameterPanel
            app.ParameterPanel = uipanel(app.MarmoV6UIFigure);
            app.ParameterPanel.ForegroundColor = [0.203921568627451 0.301960784313725 0.494117647058824];
            app.ParameterPanel.Title = 'Parameters';
            app.ParameterPanel.Visible = 'off';
            app.ParameterPanel.Tag = 'ParameterPanel';
            app.ParameterPanel.FontWeight = 'bold';
            app.ParameterPanel.FontSize = 16;
            app.ParameterPanel.Position = [26 17 265 354];

            % Create Parameters
            app.Parameters = uilistbox(app.ParameterPanel);
            app.Parameters.Items = {'Parameters'};
            app.Parameters.ValueChangedFcn = createCallbackFcn(app, @ParametersValueChanged, true);
            app.Parameters.Tag = 'Parameters';
            app.Parameters.FontSize = 13.3333333333333;
            app.Parameters.Position = [9 62 241 245];
            app.Parameters.Value = 'Parameters';

            % Create ParameterText
            app.ParameterText = uilabel(app.ParameterPanel);
            app.ParameterText.Tag = 'ParameterText';
            app.ParameterText.HorizontalAlignment = 'right';
            app.ParameterText.VerticalAlignment = 'top';
            app.ParameterText.WordWrap = 'on';
            app.ParameterText.FontSize = 13.3333333333333;
            app.ParameterText.Position = [12 41 189 18];
            app.ParameterText.Text = 'Parameter text:';

            % Create ParameterEdit
            app.ParameterEdit = uieditfield(app.ParameterPanel, 'text');
            app.ParameterEdit.ValueChangedFcn = createCallbackFcn(app, @ParameterEditValueChanged, true);
            app.ParameterEdit.Tag = 'ParameterEdit';
            app.ParameterEdit.HorizontalAlignment = 'center';
            app.ParameterEdit.FontSize = 13.3333333333333;
            app.ParameterEdit.Position = [203 37 45 23.2142857142857];

            % Create TrialCountLabel
            app.TrialCountLabel = uilabel(app.ParameterPanel);
            app.TrialCountLabel.Tag = 'TrialCountLabel';
            app.TrialCountLabel.HorizontalAlignment = 'right';
            app.TrialCountLabel.VerticalAlignment = 'top';
            app.TrialCountLabel.WordWrap = 'on';
            app.TrialCountLabel.FontSize = 13.3333333333333;
            app.TrialCountLabel.Position = [4 309 67 18];
            app.TrialCountLabel.Text = 'Trial count';

            % Create TrialMaxLabel
            app.TrialMaxLabel = uilabel(app.ParameterPanel);
            app.TrialMaxLabel.Tag = 'TrialMaxLabel';
            app.TrialMaxLabel.HorizontalAlignment = 'right';
            app.TrialMaxLabel.VerticalAlignment = 'top';
            app.TrialMaxLabel.WordWrap = 'on';
            app.TrialMaxLabel.FontSize = 13.3333333333333;
            app.TrialMaxLabel.Position = [115 309 50 18];
            app.TrialMaxLabel.Text = 'Stop at';

            % Create TrialCountText
            app.TrialCountText = uilabel(app.ParameterPanel);
            app.TrialCountText.Tag = 'TrialCountText';
            app.TrialCountText.HorizontalAlignment = 'right';
            app.TrialCountText.VerticalAlignment = 'top';
            app.TrialCountText.WordWrap = 'on';
            app.TrialCountText.FontSize = 13.3333333333333;
            app.TrialCountText.Position = [70 309 32 18];
            app.TrialCountText.Text = '0';

            % Create TrialMaxText
            app.TrialMaxText = uilabel(app.ParameterPanel);
            app.TrialMaxText.Tag = 'TrialMaxText';
            app.TrialMaxText.HorizontalAlignment = 'right';
            app.TrialMaxText.VerticalAlignment = 'top';
            app.TrialMaxText.WordWrap = 'on';
            app.TrialMaxText.FontSize = 13.3333333333333;
            app.TrialMaxText.Position = [165 308 32 18];
            app.TrialMaxText.Text = '200';

            % Create TrialMaxEdit
            app.TrialMaxEdit = uieditfield(app.ParameterPanel, 'text');
            app.TrialMaxEdit.ValueChangedFcn = createCallbackFcn(app, @TrialMaxEditValueChanged, true);
            app.TrialMaxEdit.Tag = 'TrialMaxEdit';
            app.TrialMaxEdit.HorizontalAlignment = 'center';
            app.TrialMaxEdit.FontSize = 13.3333333333333;
            app.TrialMaxEdit.Position = [201 308 51 22];

            % Create Refresh_Trials
            app.Refresh_Trials = uibutton(app.ParameterPanel, 'push');
            app.Refresh_Trials.ButtonPushedFcn = createCallbackFcn(app, @Refresh_TrialsButtonPushed, true);
            app.Refresh_Trials.Tag = 'Refresh_Trials';
            app.Refresh_Trials.FontSize = 10.6666666666667;
            app.Refresh_Trials.Position = [8 10 84 24];
            app.Refresh_Trials.Text = 'Refresh Trials';

            % Create Image
            app.Image = uiimage(app.MarmoV6UIFigure);
            app.Image.Position = [210 620 80 41];
            app.Image.ImageSource = fullfile(pathToMLAPP, 'SupportData', 'MarmosetPicture.png');

            % Create ResetGUI
            app.ResetGUI = uibutton(app.MarmoV6UIFigure, 'push');
            app.ResetGUI.ButtonPushedFcn = createCallbackFcn(app, @ResetGUIButtonPushed, true);
            app.ResetGUI.Tag = 'CloseGui';
            app.ResetGUI.FontSize = 18.6666666666667;
            app.ResetGUI.Position = [784 603 117 29];
            app.ResetGUI.Text = 'Reset GUI';

            % Show the figure after all components are created
            app.MarmoV6UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = MarmoV6

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.MarmoV6UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.MarmoV6UIFigure)
        end
    end
end