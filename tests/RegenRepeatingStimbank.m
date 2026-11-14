load('ForageRepeatingNoise_Rocky_270424_00z.mat')
%% Recall stim indices shown for each trial
nTrials=length(D);

for ii=1:nTrials
if (isfield(D{ii}.PR,'StimList'))
nShownFr=size(D{ii}.PR.NoiseHistory,1);
ShownStim{ii}=D{ii}.PR.StimList(1:nShownFr);
end
end

%% Regen stimbank parameters
% D{1}.PR.StimBankRng
o.hNoise=D{1}.PR.hNoise;
o.nFrames=2500; %this wasn't saved properly

o.hNoise.rng=D{1}.PR.StimBankRng;
reset(o.hNoise.rng);
for ii=1:o.nFrames
    o.hNoise.frameUpdate=0;
    o.hNoise.afterFrame();
    o.StimBank{ii}.x=o.hNoise.x;
    o.StimBank{ii}.y=o.hNoise.y;
    o.StimBank{ii}.mypars=o.hNoise.mypars;
end
%% Check that the parameters are correct
foundframe=0;
jj=1;
for ii=1:o.nFrames
    while foundframe==0
        if ~isempty(find(ShownStim{jj}==ii))
            foundframe=find(ShownStim{jj}==ii);
        else
            jj=jj+1;
        end
    end

    assert(ShownStim{jj}(foundframe)==ii);
    %check seed
    shownparams=(D{jj}.PR.NoiseHistory(foundframe,:));

    assert(shownparams(4)==ii); %redundant check

    seedGood(ii) = all([o.StimBank{ii}.x(1) o.StimBank{ii}.mypars(2)] == shownparams(2:3));


    %reset search
    foundframe=0;jj=1;
end

all(seedGood);

%% Regenerating full screen stimuli
binSize=1;
ROIpix=[-520  -520   520   520]; %just more than -15 to 15 for full 30 deg width
rect=round(ROIpix/binSize)*binSize;
spatialBinSize=binSize;

tmprect = rect + S.centerPix([1 2 1 2]);


% tic
% 
% %Reset stimuli to begining
% o.hNoise.rng=D{1}.PR.StimBankRng;
% reset(o.hNoise.rng);
% 
% 
% %From math
% StimFrames=zeros(1040,1040,o.nFrames,'int8');
% for ii=1:o.nFrames
%     o.hNoise.frameUpdate=0;
%     o.hNoise.afterFrame();
%     o.StimBank{ii}.x=o.hNoise.x;
%     o.StimBank{ii}.y=o.hNoise.y;
%     o.StimBank{ii}.mypars=o.hNoise.mypars;
% 
%     StimFrames(:,:,ii) = int8(o.hNoise.getImage(tmprect, spatialBinSize));
% end
% toc
% save('Rocky20240414_V2V1_RepeatingStim_Math', '-v7.3', 'StimFrames')
%% From PTB replay
A = marmoview.openScreen(S);
StimFrames=zeros(S.screenRect(4),S.screenRect(3),o.nFrames);
%%
%Reset stimuli to begining
o.hNoise.updateTextures();
o.hNoise.rng=D{1}.PR.StimBankRng;
reset(o.hNoise.rng);
%nonsense 0th frame
o.hNoise.frameUpdate=0;
o.hNoise.beforeFrame();
Screen('Flip', A.window)
o.hNoise.afterFrame();
tic
for ii=1:o.nFrames
    o.hNoise.frameUpdate=0;
    o.hNoise.beforeFrame();
    Screen('Flip', A.window)
    
    StimFrames(:,:,ii) = mean(Screen(A.window,'GetImage'),3).^(S.gamma);
    o.hNoise.afterFrame();

    o.StimBank{ii}.x=o.hNoise.x;
    o.StimBank{ii}.y=o.hNoise.y;
    o.StimBank{ii}.mypars=o.hNoise.mypars;
    
    StimFramesu8(:,:,ii)=uint8(255.*(StimFrames(:,:,ii)./(255.^S.gamma)-0.5)-0.5+128);
    newtexbank(ii)=Screen('MakeTexture', A.window, StimFramesu8(:,:,ii));

end
% 
% StimFrames=int8(255.*(StimFrames./max(StimFrames(:))-0.5)-0.5);
 toc
 %save('Rocky20240427_V2V1_RepeatingStim_int8', '-v7.3', 'StimFrames')

 %% Testrun
 tic
for ii=1:o.nFrames
    
    Screen('DrawTexture', A.window, newtexbank(ii));
    Screen('Flip', A.window)
    
end
toc
