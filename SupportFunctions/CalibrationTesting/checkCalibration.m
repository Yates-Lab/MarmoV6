%close all
load('C:\Users\Declan\Documents\2025\LukeEyeTrackingTest\Luke-20250228Eye\MV6\Luke 2025-02-28\FaceCal_Luke_280225_01z.mat')
eyeDatafull = cellfun(@(x) x.eyeData, D, 'UniformOutput', false)';
eyeDatafull = cell2mat(eyeDatafull');

c=D{end}.C.c;
dx=D{end}.C.dx;
dy=D{end}.C.dy;

MarmoviewStartTime=datetime(D{1}.STARTCLOCKTIME(1), 'ConvertFrom', 'posixtime', 'TimeZone','America/Los_Angeles', 'TicksPerSecond', 1000)

t=eyeDatafull(:,1);X=eyeDatafull(:,2);Y=eyeDatafull(:,3);

x_deg = (X-c(1)) / (dx*S.pixPerDeg);
y_deg = (Y-c(2)) / (dy*S.pixPerDeg);
%% Traces
figure(1);clf
plot(t,X,'b',t,Y,'r')
 ylim([-192.3542   94.7529]);

 scatter(X,Y,'b.')
%%
xmin=-250;xmax=-0;ymin=-80;ymax=110;
XEDGES=xmin:3:xmax;YEDGES=ymin:3:ymax;
sp=[0; hypot(diff(X),diff(Y))];
keep=X>xmin & X<xmax & Y>ymin & Y<ymax & sp<12;
[N,XEDGES,YEDGES] = histcounts2(X,Y,XEDGES,YEDGES);
figure(2);clf

X_=nan(size(X));X_(keep)=X(keep);Y_=nan(size(Y));Y_(keep)=Y(keep);
plot(t,X_,'b',t,Y_,'r')
% scatter(eyeDatafull(keep,2),eyeDatafull(keep,3),'k.')
%
%I hate this mapping
M=imgaussfilt(N,1);
imagesc(XEDGES(end:-1:1),YEDGES(end:-1:1),flipud(fliplr(M')))
axis equal tight xy; 
%check
% hold on
% scatter(eyeDatafull(:,2),eyeDatafull(:,3),'w.')

c0=clim;
clim([c0(1) 0.25*c0(2)])
%% Direct from OpenIris

%%
B=readtable('C:\Users\Declan\Documents\2025\LukeEyeTrackingTest\Luke-20250228Eye\OpenIris\FaceCal_01\Luke-2025Feb28-154326.txt');
S = table2struct(B);
R_Pp_x=[S(:).RightPupilX];
R_P1_x=[S(:).RightCR1X];
R_P1_y=[S(:).RightCR1Y];
R_P4_x=[S(:).RightCR4X];
R_P4_y=[S(:).RightCR4Y];
R_t=[S(:).RightSeconds];
%%
plot(R_t,R_Pp_x)
plot(R_t,R_P1_x-R_P4_x)
R_x=-R_P1_x+R_P4_x;
R_y=-R_P1_y+R_P4_y;
scatter(R_x,R_y,'k.')


%%
xmin=-180;xmax=-60;ymin=-40;ymax=70;
XEDGES=xmin:1.5:xmax;YEDGES=ymin:1.5:ymax;
sp=[0 hypot(diff(R_x),diff(R_y))];
keep=R_x>xmin & R_x<xmax & R_y>ymin & R_y<ymax & sp<12;
[N,XEDGES,YEDGES] = histcounts2(R_x,R_y,XEDGES,YEDGES);
figure(2);clf

R_x_=nan(size(R_x));R_x_(keep)=R_x(keep);R_y_=nan(size(R_y));R_y_(keep)=R_y(keep);
plot(R_t,R_x_,'b',R_t,R_y_,'r')

%
M=imgaussfilt(N,1);
imagesc(XEDGES(end:-1:1),YEDGES(end:-1:1),flipud(fliplr(M')))
axis equal tight xy; 
% scatter(R_x_,R_y_,'b.')

%%
for ii=3.5 %lazy loop to check delay to first trial after OpenIris starts
 t_=t-t(1)+ii;
R_t_=R_t-R_t(1);
hold off
plot(R_t_,R_x,'b-',R_t_,R_y,'r-')
hold on
plot(t_,X,'k',t_,Y,'k')

% val for 02z.mat
xlim([110 130])
ylim([-200 200])
title(ii)
pause(0.5)

end


%% Calib gui testing, bits and pieces of Jakes code. Y axis is probably flipped and unflipped somewhere (good luck)
Exp=load('C:\Users\Declan\Documents\2025\LukeEyeTrackingTest\Luke-20250228Eye\MV6\Luke 2025-02-28\FaceCal_Luke_280225_01z.mat');
Exp= import_online_eye_position(Exp);
C_gui=calibGUI(Exp);

%Calib gui uses:
% th = C_gui.cmat(3);
% R = [cosd(th) -sind(th); sind(th) cosd(th)];
% S = [C_gui.cmat(1) 0; 0 obj.cmat(2)];
% A = (R*S)';
% Ainv = pinv(A);
% 
% calib_xy = (raw_xy - C_gui.cmat(4:5))*Ainv; %Ainv handles gain and
% rotation. NOTE INVERSE!


center_xy=C_gui.cmat(4:5);
calib_gain_x=1/C_gui.cmat(1); %gain of x (not in same form!)
calib_gain_y=1/C_gui.cmat(2); %gain of y (not in same form!)


% FrameControl in MarmoView uses:
% calib_x = (raw_x-center_xy(1)) / (dx*pixPerDeg);
% calib_y = (raw_y-center_xy(2)) / (dy*pixPerDeg);

% Note division not multiplication and no rotation:
% into same form dropping rotation:   
% (raw_x - C_gui.cmat(4)) * (1/C_gui.cmat(1));

% SOOO to get back to marmoview
%(C_gui.cmat(1))=(dx*pixPerDeg); dx=cmat(1)/ppd

% Best guess from calib gui
calib_dx=C_gui.cmat(1)/Exp.S.pixPerDeg;%
calib_dy=C_gui.cmat(2)/Exp.S.pixPerDeg;