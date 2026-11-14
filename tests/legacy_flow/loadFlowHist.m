%% load the Flowhistory
%flowhis = zeros(101,600,6,300);
%zeros(81,600,6,300);
% ntrials, nFrames, nDimData, nDots 
%/home/ucla/Documents/MATLAB/MarmoV6/Output
lastCL=dir('/home/ucla/Documents/MATLAB/MarmoV6/Output/DotsflowTesting*z.mat');
[~,ind]=max([lastCL(:).datenum])
lastCL=lastCL(ind);
load([lastCL.folder filesep lastCL.name])
ntrials = size(D,1);
flowhis = zeros(ntrials,2400,6,300);
% 30 trials block - 2025
for i = 1:ntrials
    flowhis(i,:,:,:) = D{i,1}.PR.FlowHistory(1:2400,:,:);
    %D = D
    %flowhis(i,:,:,:) = D.PR.FlowHistory(1:600,:,:);
end 
save('FlowHis','-v7.3','flowhis');