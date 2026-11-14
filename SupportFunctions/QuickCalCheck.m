lastcalib=dir('./Output/FaceCal*z.mat')
[~,ind]=max([lastcalib(:).datenum])
lastcalib=lastcalib(ind);
load([lastcalib.folder filesep lastcalib.name])
Eyefull=cellfun( @(x) x.eyeData, D, 'UniformOutput', false);
Eyefullmat=cell2mat(Eyefull);

disp(lastcalib.name)

%Convert to dva
dx=D{end, 1}.C.dx
dy=D{end, 1}.C.dy
c=D{end, 1}.C.c
%%
%Lukepup200
% dx=.190;
% dy=-.190;
% c=[370 205];

% %Lukepup
% dx=.190;
% dy=-.190;
% c=[324 183];

%Lukepup
dx=.162;
dy=-.163;
c=[33.7 68.44];


% dx=.13;
% dy=-.13;
% c=[-65.5 63.7];
%
ppd=S.pixPerDeg;
x = (Eyefullmat(:,2)-c(1)) / (dx*ppd);
y = (Eyefullmat(:,3)-c(2)) / (dy*ppd);

diffx=[0; diff(x)];
diffy=[0; diff(y)];
diffxy=hypot(diffx,diffy);
ds=nanmedian(diff(Eyefullmat(:,1)));
spd=diffxy/ds;
bad= abs(x)>20 | abs(y)>20 | (abs(spd)>5); %only count fixations


%
hold off
[N,Xedges,Yedges] = histcounts2(y(~bad),x(~bad),120);
imagesc(Yedges,Xedges,imgaussfilt(N,.65));%hold on
%scatter(x,y,'w.');  %useful to double check x/y are orientated correctly
axis xy equal
xlim([-12 12]);ylim([-12 12]);

%saturate out some values
clim([0 prctile(N(:),99.5)]); 
hold on
[X,Y] = meshgrid(-10:5:10,-10:5:10);
scatter(X,Y,'w.');


%% Loop through trials
%keep only times that are 'close'

% Lukepup200
% dx=.210;
% dy=-.210;
% c=[356.87 130.08];
% 
% dx=.1241;
% dy=-.1240;
dx=.162;
dy=-.16;
c=[33.7 68.44];


% dx=.190;
% dy=-.190;
% c=[370 205];

% dx=.131;
% dy=-.131;
% c=[-65.5 66.0];
eyeall=[];
for ii=1:length(D)
    eyex = (D{ii, 1}.eyeData(:,2)-c(1)) / (dx*ppd);
    eyey = (D{ii, 1}.eyeData(:,3)-c(2)) / (dy*ppd);

    stim_locations=D{ii, 1}.PR.faceconfig;
    hold off
    scatter(stim_locations(:,1),stim_locations(:,2),'square','b')
    axis xy equal
    xlim([-12 12]);ylim([-12 12]);
    hold on
    scatter(eyex,eyey,'k.')
    distance=inf(length(eyex),1);
    for jj=1:size(stim_locations,1)
        distance_tmp=hypot(stim_locations(jj,1)-eyex,stim_locations(jj,2)-eyey);
        distance=min(distance,distance_tmp);
    end

    keep=distance<3.5;
    scatter(eyex(keep), eyey(keep),'g.')
    eyeall=[eyeall; eyex(keep) eyey(keep)];
    title(num2str(ii))
    pause(.5) %plots for debugging
end

%
hold off
% [N,Xedges,Yedges] = histcounts2(eyeall(:,2),eyeall(:,1),round(length(eyeall)/200));
[N,Xedges,Yedges] = histcounts2(eyeall(:,2),eyeall(:,1),linspace(-12,12,120),linspace(-12,12,120))
%saturate out some values
thrs=98.5;
N(N>prctile(N(:),thrs))=prctile(N(:),thrs); 

imagesc(Yedges,Xedges,imgaussfilt(N,1.25));%hold on
%scatter(x,y,'w.');  %useful to double check x/y are orientated correctly
axis xy equal
xlim([-12 12]);ylim([-12 12]);

%saturate out some values
clim([0 prctile(N(:),99.5)]); 
hold on
%scatter(eyeall(:,1),eyeall(:,2),'k.')
[X,Y] = meshgrid(-10:5:10,-10:5:10);
scatter(X,Y,'white','filled');