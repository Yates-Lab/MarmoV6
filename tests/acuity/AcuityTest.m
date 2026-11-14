%Acuity continuous

cd('C:\Users\Declan\Documents\MATLAB\MarmoV6\SupportFunctions\CalibrationTesting')
%Known ok set:
Exp=load('C:\Users\Declan\Documents\2025\LukeEyeTrackingTest\Rocky04122024_AcuityCont\Acuity_Continuous_Rocky_120424_01z.mat');
%Exp=load('C:\Users\Declan\Documents\2025\LukeEyeTrackingTest\Luke225 2025-04-25\Acuity_Continuous_Luke225_250425_00z.mat')
Exp=import_online_eye_position(Exp);
cd('C:\Users\Declan\Documents\2025\LukeEyeTrackingTest')

%%
Traces_all=cellfun(@(x) x.PR.Traces,Exp.D,'UniformOutput',false);
cpd_all=cell2mat(cellfun(@(x) x.PR.cpd,Exp.D,'UniformOutput',false));
replay_online_analysis(Traces_all, cpd_all, 240);

%% Try to improve calibration
offline_reanalysis_allTrials(Traces_all,cpd_all,240);

%% Using CCG, biased towards increased scale
offline_reanalysis_allTrials_(Traces_all,cpd_all,240);