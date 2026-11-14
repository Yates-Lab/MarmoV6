function report = test_fourierplaid_laptop(outputFolder, interactiveSeconds)
% Laptop GPU/readback and real mouse smoke test; no recording hardware used.
% Uses an uncorrected floating-point framebuffer to compare linear values.
if nargin < 1, outputFolder = fullfile(tempdir,'marmov6_spiral_laptop'); end
if nargin < 2, interactiveSeconds = 120; end
if ~exist(outputFolder,'dir'), mkdir(outputFolder); end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'Settings'),fullfile(root,'RigSettings'));
S = MarmoViewRigSettings;
assert(S.DummyScreen && strcmp(S.monitor,'Laptop'), ...
    'Select the laptop rig before running this display test.');
cleanup = onCleanup(@() Screen('CloseAll'));
InitializeMatlabOpenGL;
PsychDefaultSetup(0);
oldSkip = Screen('Preference','SkipSyncTests',1);
restoreSkip = onCleanup(@() Screen('Preference','SkipSyncTests',oldSkip));
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask','General','FloatingPoint32BitIfPossible');
screenNumber = S.screenNumber;
windowPosition = S.screenRect;
assert(all(windowPosition(1:2)==0), ...
    'This test verifies the laptop window at the screen origin.');
[win, rect] = PsychImaging('OpenWindow',screenNumber,127.5,windowPosition);
rect = [0 0 RectWidth(rect) RectHeight(rect)];
stim = stimuli.fourierplaid_procedural(win,'screenRect',rect, ...
    'pixPerDeg',S.pixPerDeg,'K',6,'contrast',0.30, ...
    'maxSF',4,'ns',6,'frameRate',60,'bgGrey',0.5);
report.gpuCPU = validate_fourierplaid_gpu_cpu(stim);
assert(all([report.gpuCPU.maximumAbsoluteError] <= 2/255), ...
    'GPU and CPU disagree by more than two 8-bit levels.');
report.windowPosition = windowPosition;
report.actualWindowPosition = Screen('GlobalRect',win);
report.screenPosition = Screen('GlobalRect',screenNumber);
report.mouseFunction = which('GetMouse');
report.renderer = opengl('data');
report.presets = struct([]);
presets = {'Forage_RandomPhaseHyperplaid_Spiral', ...
    'Forage_RandomPhaseHyperplaid_Pminus1_4cpd_5648', ...
    'Forage_RandomPhaseHyperplaid_Pminus2_16cpd_2800'};
for k = 1:numel(presets)
    [~,P] = feval(presets{k});
    stim.K = P.hp_K;
    stim.contrast = P.noiseContrast;
    maxSF = P.hp_maxSF;
    if isfield(P,'hp_spiralMaxSF'), maxSF = P.hp_spiralMaxSF; end
    stim.configureSpiralBank(P.hp_spiralTargetCount,maxSF, ...
        P.hp_spiralDensityExponent,P.hp_spiralMinSF,P.hp_spiralAxisCount);
    stim.beforeTrial();
    stim.beforeFrame();
    Screen('Flip',win);
    report.presets(k).bank = stim.spiralBankInfo;
    report.presets(k).name = presets{k};
    report.presets(k).history = stim.currentLogRowNumeric(GetSecs);
    gpu = mean(Screen('GetImage',win,rect,[],1),3);
    cpu = double(stim.getImage(rect,1))/255;
    delta = gpu-cpu;
    report.presets(k).rmse = sqrt(mean(delta(:).^2));
    report.presets(k).maxError = max(abs(delta(:)));
    assert(report.presets(k).maxError <= 2/255, ...
        'Spiral mixture GPU/CPU mismatch.');
    imwrite(Screen('GetImage',win),fullfile(outputFolder,sprintf('spiral_%d.png',k)));
end
tracker = marmoview.eyetrack_dummy(struct('ScreenNumber',screenNumber));
calibration = tracker.calibinit(S);
report.mouseCalibration = calibration;
report.mouseSamples = zeros(0,7);
stim.configureSpiralBank(2000,4,-1,0,0);
fprintf('LAPTOP_MOUSE_READY: move/click inside the spiral window.\n');
started = GetSecs;
while GetSecs-started < interactiveSeconds
    stim.sampleComponents();
    stim.beforeFrame();
    [x,y] = tracker.getgaze([]);
    [wx,wy,buttons] = GetMouse(win);
    report.mouseSamples(end+1,:) = [GetSecs-started,x,y,wx,wy,any(buttons),tracker.getpupil()];
    Screen('FillOval',win,[1 0 0],[wx-5 wy-5 wx+5 wy+5]);
    Screen('Flip',win);
    if any(buttons)
        fprintf('Mouse screen=(%.0f,%.0f), window=(%.0f,%.0f)\n',x,y,wx,wy);
    end
    if exist(fullfile(outputFolder,'stop'),'file'), break; end
    WaitSecs(0.1);
end
report.mouseOffsetError = max(abs(report.mouseSamples(:,2:3) - ...
    report.mouseSamples(:,4:5) - S.screenRect(1:2)),[],1);
% Calls are sequential: motion between them can produce occasional outliers.
report.mouseMedianOffsetError = median(abs(report.mouseSamples(:,2:3) - ...
    report.mouseSamples(:,4:5) - S.screenRect(1:2)),1);
save(fullfile(outputFolder,'report.mat'),'report');
fid = fopen(fullfile(outputFolder,'summary.json'),'w');
fprintf(fid,'%s',jsonencode(rmfield(report,{'mouseSamples','renderer'})));
fclose(fid);
fprintf('Mouse offset errors: %.3f %.3f pixels.\n',report.mouseOffsetError);
stim.CloseUp();
end
