%% --- Demo: Hartley Hyperplaid (static, K components per frame) ---

% For quick testing only (disable in real experiments)
Screen('Preference','SkipSyncTests',1);

% Rig / screen
S = MarmoViewRigSettings;
S.screenRect = [0 0 600 500];        % demo window
A = marmoview.openScreen(S);
ifi = Screen('GetFlipInterval', A.window);
S.frameRate = round(1/ifi);

% --- Construct the hyperplaid stimulus
% Key params: 60 Hz, K=6, independent frames (updateEveryNFrames=1)
hpl = stimuli.hyperplaid_static(A.window, ...
    'screenRect',            A.screenRect, ...
    'pixPerDeg',             S.pixPerDeg, ...
    'frameRate',             S.frameRate, ...
    'K',                     6, ...              % components per frame
    'contrast',              0.40, ...
    'basisMode',             'hartley', ...      % use Hartley cas basis
    'useHartleyLattice',     true, ...
    'spatialFrequencies',    3 * 2.^linspace(-1,1,5), ... % 5 rings (cpd)
    'updateEveryNFrames',    1, ...              % new set every frame
    'uniquePerFrame',        true ...            % no repeat within a frame
    );

% (Optional) tighten SF band per animal:
% hpl.spatialFrequencies_cpd = [1.5 2.1 2.9 4.0 5.6];

% Prep textures and internal state
hpl.updateTextures();
hpl.beforeTrial();    % seeds RNG and samples first frame

% --- Per-frame numeric log (time, frame#, K, amp, then fx,fy,phi,idx × K)
durSec = 8;                                   % demo duration
nF     = round(durSec * S.frameRate);
K      = hpl.K;
cols   = 4 + 4*K;                             % [t, f#, K, amp, (fx,fy,phi,idx)xK]
Log    = nan(nF, cols);

% Flip once to get a VBL timestamp anchor
vbl = Screen('Flip', A.window);

try
    for f = 1:nF
        % Draw current frame
        hpl.beforeFrame();

        % Show it
        vbl = Screen('Flip', A.window, vbl + 0.5*ifi);

        % Advance internal state (resamples when frameUpdate hits 0)
        hpl.afterFrame();

        % --- Per-frame logging (numeric, fixed width)
        cur = hpl.current;
        if isfield(cur,'fx')
            fx = cur.fx(:)';  fy = cur.fy(:)';
        else
            th = deg2rad(cur.ori(:)'); sf = cur.sf(:)';
            fx = sf .* cos(th);         fy = sf .* sin(th);
        end
        phi = cur.phi(:)';   % phase *sent* this frame (radians)
        idx = cur.idx(:)';   % integer index into hpl.bank (Hartley lattice)

        amp = hpl.contrast / sqrt(max(K,1));
        row = nan(1, cols);
        row(1:4) = [vbl, f, K, amp];

        % Pack K-tuples as [fx1 fy1 phi1 idx1 | fx2 fy2 phi2 idx2 | ...]
        p = 5;
        for j = 1:K
            row(p:(p+3)) = [fx(j) fy(j) phi(j) idx(j)];
            p = p + 4;
        end
        Log(f,:) = row;
    end

    % --- Optional: GPU↔CPU parity check on the *last* drawn frame
    gpuImg = Screen('GetImage', A.window, A.screenRect, [], [], 1); % fast=1
    cpuImg = hpl.getImage(A.screenRect, 1);
    maxAbsErr = max(abs(double(gpuImg(:)) - double(cpuImg(:))));
    fprintf('Hyperplaid getImage parity: max abs pixel diff = %g\n', maxAbsErr);

catch ME
    disp(getReport(ME,'extended'));
end

% --- Cleanup
if exist('hpl','var') && isa(hpl,'stimuli.stimulus')
    hpl.CloseUp();
end
sca;
