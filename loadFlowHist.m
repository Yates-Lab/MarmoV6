%% load the Flowhistory
flowhis = zeros(100,600,5,300);

for i = 1:100
    flowhis(i,:,:,:) = D{i,1}.PR.FlowHistory(1:600,:,:);
end 
save('FlowHis','flowhis');