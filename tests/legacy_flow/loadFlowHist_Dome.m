%% load the Flowhistory - Dome rig 
%flowhis = zeros(101,600,6,300);
%zeros(81,600,6,300);
% ntrials, nFrames, nDimData, nDots 
flowhis = zeros(92,2400,6,300);

for i = 1:81
    flowhis(i,:,:,:) = D{i,1}.PR.FlowHistory(1:2400,:,:);
    %D = D
    %flowhis(i,:,:,:) = D.PR.FlowHistory(1:600,:,:);
end 
save('FlowHis','-v7.3','flowhis');