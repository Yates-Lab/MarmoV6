function demo_hyperplaid_with_class()
% Uses stimuli.hyperplaid_static to render example frames via getImage.

Screen('Preference','SkipSyncTests',1);   % testing only
S = MarmoViewRigSettings;
S.screenRect = [0 0 1280 720];

A = marmoview.openScreen(S);
ifi = Screen('GetFlipInterval', A.window);
S.frameRate = round(1/ifi);

% Build the hyperplaid (Hartley mode, full-field)
hpl = stimuli.hyperplaid_static(A.window, ...
    'screenRect',            A.screenRect, ...
    'pixPerDeg',             S.pixPerDeg, ...
    'frameRate',             S.frameRate, ...
    'basisMode',             'hartley', ...
    'useHartleyLattice',     true, ...
    'spatialFrequencies',    3*2.^linspace(-1,1,5), ...
    'K',                     6, ...
    'contrast',              0.4, ...
    'updateEveryNFrames',    1, ...
    'uniquePerFrame',        true);

hpl.updateTextures();
hpl.beforeTrial();

nFrames = 9;
figure('Color','w','Name','Class Hyperplaid Demo'); colormap(gray);
for f = 1:nFrames
    % NOTE: no need to draw/flip; getImage uses current params on CPU
    I = hpl.getImage(A.screenRect, 1);
    subplot(3,3,f); imagesc(I); axis image off;

    % Make a compact title with a few components’ (ori°, sf cpd)
    K = hpl.K;
    ori = hpl.current.ori(:)'; sf = hpl.current.sf(:)';
    show = min(K,3);
    frag = join( compose('%.0f°@%.2f', ori(1:show), sf(1:show)), '  ' );
    title(sprintf('Frame %d  |  K=%d  |  %s...', f, K, frag{1}));

    % Advance to next random set
    hpl.afterFrame();
end

% Cleanup
hpl.CloseUp();
marmoview.closeScreen(A);
end
