%% open Screen
%Screen('Preference', 'SkipSyncTests', 1); %For testing only
S = MarmoViewRigSettings;
%S.screenRect = [0 0 600 500];
A = marmoview.openScreen(S);

%%
dotflow=stimuli.opticflow(A.window);

%Position is relative to top left
dotflow.position= [(S.screenRect(3)+S.screenRect(1))/2 (S.screenRect(4)+S.screenRect(2))/2];
dotflow.f= 0.0100;
dotflow.depth= 2;
dotflow.size= 3;
dotflow.vxyz= [0 0 .1];
dotflow.nDots= 500;
dotflow.transparent= 0.5000;
dotflow.pixperdeg= S.pixPerDeg;
dotflow.screenRect= A.screenRect;
dotflow.colour= [1 1 1];
dotflow.bkgd= 127;
dotflow.maxRadius= inf;
dotflow.Xtop=  A.screenRect(3);
dotflow.Xbot=  A.screenRect(1);
dotflow.Ytop=  A.screenRect(2);
dotflow.Ybot=  A.screenRect(4);

dotflow.beforeTrial()
dotflow.stimValue = 1;
dotflow.beforeFrame()


Screen('Flip', A.window)
%%
for i = 1:1000
    dotflow.position =  [(S.screenRect(3)+S.screenRect(1))/2 (S.screenRect(4)+S.screenRect(2))/2] + [cosd(i) sind(i)]*15;

    dotflow.beforeFrame()
    Screen('Flip', A.window);
    dotflow.afterFrame()
    %dotflow.x(1)
    pause(0.01)

end


%% Grating/mouse interaction

grat = stimuli.grating(A.window);

grat.position = A.screenRect(3:4)/2;
grat.screenRect = A.screenRect;
grat.pixperdeg = S.pixPerDeg;

grat.cpd = 15;
grat.radius = 100; % in pixels (also note, this is the diameter, I think)
grat.orientation = 90; % in degrees
grat.phase = 0;

grat.range = 127; % color range
grat.square = false; % if you want a hard aperture
grat.gauss = true;
grat.bkgd = S.bgColour;
grat.transparent = 0.5; % effectively Michelson contrast / 2 -- again, worth checking

grat.updateTextures()
grat.stimValue = 1;
grat.beforeFrame()


Screen('Flip', A.window)


%% interact with mouse input
[x0,y0] = GetMouse();

for i = 1:1000
%     grat.position = grat.position + randn(1,2)*2;
    [x,y] = GetMouse();
    grat.phase = grat.phase + (x - x0);
    x0 = x;
    grat.beforeFrame()
    Screen('Flip', A.window)
end