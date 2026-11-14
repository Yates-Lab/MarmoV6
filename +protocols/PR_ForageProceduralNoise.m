classdef PR_ForageProceduralNoise < protocols.protocol
  % Forage protocol with procedural background noise
  %
  % The class constructor can be called with a range of arguments:
  %
 
  properties (Access = public)
       itiStart double = 0;        % start of iti interval
       rewardCount double = 0;     % counter for reward drops
       rewardGap double = 0;       % gap for next target onset
       rewardTime double = 0;      % store time of last reward
  end
      
  properties (Access = public)
    trialsList        % store copy of trial list (not good to keep in S struct)
    
    %********* stimulus structs for use
    Faces             % object that stores face images for use
    faceTime = 0.1    % time for showing face stimulus
    hProbe = []       % object for foraging stimuli
    probeNum = 1      % number of foraging stimuli
    oriNum = 1        % number of oriented textures to draw from for probe
    targOri = 1       % current orientation of target probe
    hNoise = []       % random flashing background grating
    noiseNum = 1      % number of oriented textures
    spatoris = []     % list of tested orientations
    spatfreqs = []    % list of tested spatial freqs
    %******* parameters for Noise History grating stimulus 
    noisetype = 0     % type of background noise stimulus
    NoiseHistory = [] % list of noise frames over trial and their times
    FrameCount = 0    % count noise frames
    ProbeHistory = [] % list of history for probe objects
    PFrameCount = 0   % count probe frames (should be same as noise for now)
    MaxFrame = []     % twenty second maximum
    TrialDur = 0;     % store internally the trial duration (make less than 20)
    %******** parameters for positioning foraging stimuli
    PosList = []      % will be x,y positions of stimuli
    MovList = []      % speed vector if a moving item
    FixTime = 0      % will be duration item is fixated
    MovStep = 0       % vector amplitude motion step if moving probe
    %*******
    FixCount = 0      % count fixation of probe events
    FixHit = []       % list of positions where probe hits occured
    FixMax = 20        % maximum fixations in any trial
    %**** Photodiode flash timing
    Flashtime = [];
    %**********************************
    D struct = struct()        % store PR data for end plot stats, will store dotmotion array
  end
  
  methods (Access = public)
    function o = PR_ForageProceduralNoise(winPtr)
        o = o@protocols.protocol(winPtr);
    end
    
    function initFunc(o,S,P)
  
       %********** Set-up for trial indexing (required) 
       cors = [0,4];  % count these errors as correct trials
       reps = [1,2];  % count these errors like aborts, repeat
       o.trialsList = [];  % empty for this protocol
       %**********
      
       %******* init Noise History with MaxDuration **************
       o.MaxFrame = ceil(20*S.frameRate);
       o.ProbeHistory = zeros(o.MaxFrame,4);  % x,y,ori,fixated
       
       %******* init reward face for correct trials
       o.faceTime = P.faceTime;
       o.Faces = stimuli.gaussimages(o.winPtr,'bkgd',S.bgColour,'gray',false);   % color images
       o.Faces.loadimages('./SupportData/MarmosetFaceLibrary.mat');
       o.Faces.position = [0,0]*S.pixPerDeg + S.centerPix;
       o.Faces.radius = round(P.faceradius*S.pixPerDeg);
       o.Faces.imagenum = 1;  % start first face
       o.Faces.transparency = -1;  % blend into background

       %***** create a Gabor target grating
       o.FixTime = 0;
       o.oriNum = P.orinum;
       o.hProbe = cell(1,o.oriNum);
       o.targOri = 1;
       for kk = 1:o.oriNum
           %*******
           o.hProbe{kk} = stimuli.grating(o.winPtr);  % grating probe
           o.hProbe{kk}.transparent = -P.probecon;  % blend in proportion to gauss
           o.hProbe{kk}.gauss = true;
           o.hProbe{kk}.pixperdeg = S.pixPerDeg;
           o.hProbe{kk}.radius = round(P.proberadius*S.pixPerDeg);
          
           o.hProbe{kk}.range = P.proberange;
           o.hProbe{kk}.square = false;
           o.hProbe{kk}.bkgd = P.bkgd;
           %**************
           o.hProbe{kk}.position = [S.centerPix(1),S.centerPix(2)];
           o.hProbe{kk}.phase = P.phase;
           o.hProbe{kk}.cpd = P.cpd;
           if (kk < o.oriNum)
              if (kk == 1)
                 o.hProbe{kk}.orientation = P.prefori;
              else
                 o.hProbe{kk}.orientation = P.nonprefori;
                 o.hProbe{kk}.cpd = P.noncpd;
              end
              %o.hProbe{kk}.orientation = (kk-1)*180/(o.oriNum-1);
              %o.hProbe{kk}.orientation = o.hProbe{kk}.orientation + P.prefori;
           else
              o.hProbe{kk}.orientation = 0; 
              o.hProbe{kk}.cpd = 0;
              o.hProbe{kk}.phase = 0;
           end
           %**************
           o.hProbe{kk}.updateTextures();
           %****************
       end
       %***** but don't set stim properties yet ... done per trial
       
       %******* SETUP NOISE BACKGROUND BASED ON TYPE, HARTLEY, SPATIAL, ETC
       o.noisetype = P.noisetype;
       %**********
       
       switch o.noisetype
           
           %***************************************************************
           % for o.noisetype == 0 would be no background at all!
           case 0 % no background
               o.noiseNum = 0;
               o.hNoise = [];
               
           %***************************************************************
           case 1 % "Hartley" background
               
               o.NoiseHistory = nan(o.MaxFrame,3);
               
               % select spatial frequencies
               if (P.spfnum > 1) && (P.spfmax > P.spfmin)
                   o.spatfreqs = exp( log(P.spfmin):(log(P.spfmax)-log(P.spfmin))/(P.spfnum-1):log(P.spfmax));
               else
                   o.spatfreqs = ones(1,P.spfnum) * P.spfmax;
               end
               
               % select possible orientations
               o.spatoris = (0:(P.noiseorinum-1))*180/P.noiseorinum;
               if (isfield(P,'orioffset'))
                   o.spatoris = o.spatoris + P.orioffset;
               end
               o.noiseNum = P.noiseorinum * P.spfnum;
               
               % noise object is created here
               o.hNoise = stimuli.gratingFFnoise(o.winPtr, 'pixPerDeg', S.pixPerDeg);
               o.hNoise.numOrientations = P.noiseorinum;
               o.hNoise.orientations = o.spatoris;
               o.hNoise.spatialFrequencies = o.spatfreqs;
               o.hNoise.randomizePhase = P.noiseRandomizePhase;
               o.hNoise.updateEveryNFrames = ceil(S.frameRate / P.noiseFrameRate);
               o.hNoise.updateTextures(); % create the procedural texture
               o.hNoise.contrast = P.noiseContrast;
               
               
           %***************************************************************
           case 2 % use Spatial reverse correlation background
               o.noiseNum = P.snoisenum * 2;
               o.NoiseHistory = nan(o.MaxFrame,(1+(o.noiseNum * 2)));  % store time, then x,y positions
               o.hNoise = cell(1,o.noiseNum);
               
               for k = 1:o.noiseNum
                   o.hNoise{k} = stimuli.grating_procedural(o.winPtr);  % grating probe
                   o.hNoise{k}.radius = round((P.snoisediam/2)*S.pixPerDeg);
                   o.hNoise{k}.orientation = 0; % cpd will be zero => all one color
                   if (mod(k,2) == 1)
                       o.hNoise{k}.phase = 0;   % white
                   else
                       o.hNoise{k}.phase = 180; % black
                   end
                   o.hNoise{k}.cpd = 0; % when cpd is zero, you get a Gauss
                   o.hNoise{k}.range = P.range;
                   o.hNoise{k}.square = false; % true;  % if you want circle
                   o.hNoise{k}.gauss = true;
                   o.hNoise{k}.bkgd = P.bkgd;
                   o.hNoise{k}.transparent = -0.5;
                   o.hNoise{k}.pixperdeg = S.pixPerDeg;
                   o.hNoise{k}.updateTextures();
               end
               
           %***************************************************************
           case 3 % CSD flash
               
               % CSD will be similar to hartley, but all white (SF=0)
               % and a different on duration of stimulus
               
               o.NoiseHistory = nan(o.MaxFrame,2);
               o.noiseNum = 1;
               o.hNoise = [];
           
           %***************************************************************
           case 4 % Garborium noise
               o.NoiseHistory = nan(o.MaxFrame,3);
               
               % noise object is created here
               o.hNoise = stimuli.gabornoise(o.winPtr, 'pixPerDeg', S.pixPerDeg, 'numGabors', P.numGabors);
               
               x = P.noiseCenterX*S.pixPerDeg + S.centerPix(1);
               y = -P.noiseCenterY*S.pixPerDeg + S.centerPix(2);
               o.hNoise.position = [x y];
               o.hNoise.radius = P.noiseRadius * S.pixPerDeg;
               o.hNoise.contrast = P.noiseContrast;
               o.hNoise.scaleRange = P.scaleRange;
               o.hNoise.minScale = P.minScale;
               o.hNoise.minSF = P.spfmin;
               o.hNoise.sfRange =  P.spfrange;
               
               o.hNoise.updateEveryNFrames = ceil(S.frameRate / P.noiseFrameRate);
               o.hNoise.updateTextures(); % create the procedural texture
               
           case 5 % dot spatial noise
               o.noiseNum = min(P.numDots, 100); % only store up to 500 dots
               o.NoiseHistory = nan(o.MaxFrame,(1+(o.noiseNum * 2))); 
               % noise object is created here
               o.hNoise = stimuli.dotspatialnoise(o.winPtr, 'numDots', P.numDots, ...
                   'sigma', P.noiseApertureSigma*S.pixPerDeg);
               o.hNoise.contrast = P.noiseContrast;
               o.hNoise.size = P.dotSize * S.pixPerDeg;
               o.hNoise.speed = P.dotSpeedSigma * S.pixPerDeg / S.frameRate;
               o.hNoise.updateEveryNFrames = ceil(S.frameRate / P.noiseFrameRate);
           
           %***************************************************************
           case 6 % Drifting grating background
        
               o.NoiseHistory = nan(o.MaxFrame,7); % time, orientation, cpd, phase, direction, speed, contrast
               
               % position
               x = P.GratCtrX*S.pixPerDeg + S.centerPix(1);
               y = -P.GratCtrY*S.pixPerDeg + S.centerPix(2);
               
               % noise object is created here
               o.hNoise = stimuli.grating_drifting(o.winPtr, ...
                    'numDirections', P.numDir, ...
                    'minSF', P.GratSFmin, ...
                    'numOctaves', P.GratNumOct, ...
                    'pixPerDeg', S.pixPerDeg, ...
                    'frameRate', S.frameRate, ...
                    'speeds', P.GratSpeed, ...
                    'position', [x y], ...
                    'screenRect', S.screenRect, ...
                    'diameter', P.GratDiameter, ...
                    'durationOn', P.GratDurOn, ...
                    'durationOff', P.GratDurOff, ...
                    'isiJitter', P.GratISIjit, ...
                    'contrasts', P.GratCon, ...
                    'randomizePhase', P.RandPhase);
                
               o.hNoise.updateTextures(); % create the procedural texture


           case 7 % Denser Garborium noise
               o.NoiseHistory = nan(o.MaxFrame,3);
               
               % noise object is created here
               o.hNoise = stimuli.densegabornoise(o.winPtr, 'pixPerDeg', S.pixPerDeg, 'numGabors', P.numGabors);
               
               x = P.noiseCenterX*S.pixPerDeg + S.centerPix(1);
               y = -P.noiseCenterY*S.pixPerDeg + S.centerPix(2);
               o.hNoise.position = [x y];
               o.hNoise.radius = P.noiseRadius * S.pixPerDeg;
               o.hNoise.contrast = P.noiseContrast;
               o.hNoise.scaleRange = P.scaleRange;
               o.hNoise.minScale = P.minScale;
               o.hNoise.minSF = P.spfmin;
               o.hNoise.sfRange =  P.spfrange;
               
               o.hNoise.updateEveryNFrames = ceil(S.frameRate / P.noiseFrameRate);
               o.hNoise.updateTextures(); % create the procedural texture
                %***************************************************************
           case 8 % Superimposed quartets gratings background
               o.NoiseHistory = nan(o.MaxFrame,1+6*4); % time, orientation, cpd, phase, direction, speed, contrast

               % position
               x = P.GratCtrX*S.pixPerDeg + S.centerPix(1);
               y = -P.GratCtrY*S.pixPerDeg + S.centerPix(2);
                              % noise object is created here
               o.hNoise = stimuli.superimposed_sine_quartet(o.winPtr, ...
                    'numDirections', P.numDir, ...
                    'numPhases', P.numPhase, ...
                    'minSF', P.GratSFmin, ...
                    'numOctaves', P.GratNumOct, ...
                    'pixPerDeg', S.pixPerDeg, ...
                    'frameRate', S.frameRate, ...
                    'speeds', P.GratSpeed, ...
                    'position', [x y], ...
                    'screenRect', S.screenRect, ...
                    'diameter', P.GratDiameter, ...
                    'durationOn', P.GratDurOn, ...
                    'durationOff', P.GratDurOff, ...
                    'isiJitter', P.GratISIjit, ...
                    'contrasts', P.GratCon, ...
                    'randomizePhase', false); % DO NOT RANDOMISE PHASE
              % o.hNoise.updateEveryNFrames = ceil(S.frameRate / P.noiseFrameRate);
               o.hNoise.updateTextures(); % create the procedural texture
               
          case 9 % Superimposed quartets gratings background
               o.NoiseHistory = nan(o.MaxFrame,1+6*4); % time, orientation, cpd, phase, direction, speed, contrast

               % position
               x = P.GratCtrX*S.pixPerDeg + S.centerPix(1);
               y = -P.GratCtrY*S.pixPerDeg + S.centerPix(2);
                              % noise object is created here
               o.hNoise = stimuli.superimposed_sine_pair(o.winPtr, ...
                    'numDirections', P.numDir, ...
                    'numPhases', P.numPhase, ...
                    'minSF', P.GratSFmin, ...
                    'numOctaves', P.GratNumOct, ...
                    'pixPerDeg', S.pixPerDeg, ...
                    'frameRate', S.frameRate, ...
                    'speeds', P.GratSpeed, ...
                    'position', [x y], ...
                    'screenRect', S.screenRect, ...
                    'diameter', P.GratDiameter, ...
                    'durationOn', P.GratDurOn, ...
                    'durationOff', P.GratDurOff, ...
                    'isiJitter', P.GratISIjit, ...
                    'contrasts', P.GratCon, ...
                    'prefori', P.prefori, ...
                    'randomizePhase', false); % DO NOT RANDOMISE PHASE
              % o.hNoise.updateEveryNFrames = ceil(S.frameRate / P.noiseFrameRate);
               o.hNoise.updateTextures(); % create the procedural texture

           case 10 % Drifting grating background but with independant SF/TF
        
               o.NoiseHistory = nan(o.MaxFrame,7); % time, orientation, cpd, phase, direction, TF, contrast
               
               % position
               x = P.GratCtrX*S.pixPerDeg + S.centerPix(1);
               y = -P.GratCtrY*S.pixPerDeg + S.centerPix(2);
               
               % noise object is created here
               o.hNoise = stimuli.grating_drifting_TFs(o.winPtr, ...
                    'numDirections', P.numDir, ...
                    'minSF', P.GratSFmin, ...
                    'numOctaves', P.GratNumOct, ...
                    'pixPerDeg', S.pixPerDeg, ...
                    'frameRate', S.frameRate, ...
                    'minTF', P.GratTFmin, ...
                    'nTFs',  P.nTFs, ...
                    'position', [x y], ...
                    'screenRect', S.screenRect, ...
                    'diameter', P.GratDiameter, ...
                    'durationOn', P.GratDurOn, ...
                    'durationOff', P.GratDurOff, ...
                    'isiJitter', P.GratISIjit, ...
                    'contrasts', P.GratCon, ...
                    'randomizePhase', P.RandPhase);
                
               o.hNoise.updateTextures(); % create the procedural texture

           case 11 % Drifting grating background but with independant SF/TF, and doubling octaves
        
               o.NoiseHistory = nan(o.MaxFrame,7); % time, orientation, cpd, phase, direction, TF, contrast
               
               % position
               x = P.GratCtrX*S.pixPerDeg + S.centerPix(1);
               y = -P.GratCtrY*S.pixPerDeg + S.centerPix(2);
               
               % noise object is created here
               o.hNoise = stimuli.grating_drifting_TFSFx4(o.winPtr, ...
                    'numDirections', P.numDir, ...
                    'minSF', P.GratSFmin, ...
                    'numOctaves', P.GratNumOct, ...
                    'pixPerDeg', S.pixPerDeg, ...
                    'frameRate', S.frameRate, ...
                    'minTF', P.GratTFmin, ...
                    'nTFs',  P.nTFs, ...
                    'position', [x y], ...
                    'screenRect', S.screenRect, ...
                    'diameter', P.GratDiameter, ...
                    'durationOn', P.GratDurOn, ...
                    'durationOff', P.GratDurOff, ...
                    'isiJitter', P.GratISIjit, ...
                    'contrasts', P.GratCon, ...
                    'randomizePhase', P.RandPhase);

               o.hNoise.updateTextures(); % create the procedural texture


           case 14 % Full-field static hartleyplaid (K superimposed gratings; tight grid)

               hp_K = P.hp_K;
               o.NoiseHistory = nan(o.MaxFrame, 1 + 1 + 4*hp_K);  % [time | K | (fx fy amp idx) × K] -phi is fixed

               equalStride = false;
               if isfield(P, 'equalStride')
                   equalStride = P.equalStride;
               end

               %                     fx  = row(2 + (0:(nK-1)));
               %                     fy  = row(2 + nK + (0:(nK-1)));
               %                     amp = row(2 + 2*nK + (0:(nK-1)));
               %                     idx = row(2 + 3*nK + (0:(nK-1)));
               %                     I(x,y) = bgGrey + sum_j amp(j)*sin(2*pi*(fx(j)*X + fy(j)*Y) - pi/4);

               % Build the tight grid from screen geometry:
               % Wdeg = RectWidth(S.screenRect)/S.pixPerDeg;
               % Hdeg = RectHeight(S.screenRect)/S.pixPerDeg;

               % % Auto-pick strides from ns unless user overrides:
               ns = P.hp_ns;
               % if isempty(P.hp_strideKx) || isempty(P.hp_strideKy)
               %     [sx, sy, info] = pickHartleyStridesFromNs(Wdeg, Hdeg, P.hp_maxSF, P.hp_maxSF, ns);
               % else
               %     sx   = P.hp_strideKx;
               %     sy   = P.hp_strideKy;
               %     info = struct('nx', 2*floor(floor(Wdeg*P.hp_maxSF)/sx)+1, ...
               %         'ny', 2*floor(floor(Hdeg*P.hp_maxSF)/sy)+1, ...
               %         'N_total', []);
               % end
               % fprintf('[hartleyplaid] sx=%d sy=%d | nx=%d ny=%d | maxSF=%.2f c/deg\n', ...
               %     sx, sy, info.nx, info.ny, P.hp_maxSF);

               % Instantiate the pre-rendered 8-bit texture bank (tight rectangular grid, no disk)
               o.hNoise = stimuli.hartleyplaid_procedural(o.winPtr, ...
                   'screenRect', S.screenRect, ...
                   'pixPerDeg',  S.pixPerDeg, ...
                   'frameRate',  S.frameRate, ...
                   'maxSF',      P.hp_maxSF, ...
                   'K',          hp_K, ...
                   'ns',         P.hp_ns, ...
                   'equalStride', equalStride, ...
                   'contrast',   P.noiseContrast, ...
                   'updateEveryNFrames', ceil(S.frameRate / P.noiseFrameRate), ...
                   'bgGrey',     S.bgColour);

               %Automatic:
               %o.hNoise.updateTextures();  % pre-render the atom bank
               % 
               % 
               % stim = hartleyplaid_procedural(winPtr, ...
               %     'screenRect', screenRect, ...
               %     'pixPerDeg', pixPerDeg, ...
               %     'maxSF', 8, ...
               %     'ns', 25, ...             % target samples per axis
               %     'equalStride', true);     % isotropic stride mode
               % 
               % 
               % vs
               % 
               % stim = hartleyplaid_procedural(winPtr, ...
               %     'screenRect', screenRect, ...
               %     'pixPerDeg', pixPerDeg, ...
               %     'maxSF', 8, ...
               %     'ns', Inf, ...           % full integer lattice
               %     'equalStride', false);

           case 15 % Random-phase Fourier hyperplaid on the Hartley lattice

               hp_K = P.hp_K;
               % [time | K | fx(1:K) | fy(1:K) | phase(1:K) |
               %  amplitude(1:K) | bankIndex(1:K)]
               o.NoiseHistory = nan(o.MaxFrame, 1 + 1 + 5*hp_K);

               o.hNoise = stimuli.fourierplaid_procedural(o.winPtr, ...
                   'screenRect', S.screenRect, ...
                   'pixPerDeg',  S.pixPerDeg, ...
                   'frameRate',  S.frameRate, ...
                   'maxSF',      P.hp_maxSF, ...
                   'K',          hp_K, ...
                   'ns',         P.hp_ns, ...
                   'equalStride', P.equalStride, ...
                   'contrast',   P.noiseContrast, ...
                   'updateEveryNFrames', ceil(S.frameRate / P.noiseFrameRate), ...
                   'bgGrey',     S.bgColour);

               if isfield(P, 'hp_spiralBank') && P.hp_spiralBank
                   spiralCount = 2000;
                   if isfield(P, 'hp_spiralTargetCount')
                       spiralCount = P.hp_spiralTargetCount;
                   end
                   spiralMaxSF = P.hp_maxSF;
                   if isfield(P, 'hp_spiralMaxSF')
                       spiralMaxSF = P.hp_spiralMaxSF;
                   end
                   spiralDensityExponent = -1;
                   if isfield(P, 'hp_spiralDensityExponent')
                       spiralDensityExponent = P.hp_spiralDensityExponent;
                   end
                   spiralMinSF = 0;
                   if isfield(P, 'hp_spiralMinSF')
                       spiralMinSF = P.hp_spiralMinSF;
                   end
                   spiralAxisCount = 0;
                   if isfield(P, 'hp_spiralAxisCount')
                       spiralAxisCount = P.hp_spiralAxisCount;
                   end
                   o.hNoise.configureSpiralBank(spiralCount, spiralMaxSF, ...
                       spiralDensityExponent, spiralMinSF, spiralAxisCount);
                   fprintf(['Golden spiral Fourier bank: %d physical axes ' ...
                       'from %d proposals (%.3g cpd radial limit, p=%.3g).\n'], ...
                       o.hNoise.spiralBankInfo.physicalAxisCount, ...
                       o.hNoise.spiralBankInfo.proposalCountUsed, o.hNoise.spiralMaxSF, ...
                       o.hNoise.spiralDensityExponent);
               end



       end
       %**********************************************************
       
    end
   
    function closeFunc(o)
        o.Faces.CloseUp();
        for kk = 1:o.probeNum
           o.hProbe{kk}.CloseUp();
        end
        if iscell(o.noiseNum) % backwards compatible with old-style noise
            for kk = 1:o.noiseNum
                if ~isempty(o.hNoise{kk})
                    o.hNoise{kk}.CloseUp();
                end
            end
        elseif isa(o.hNoise, 'stimuli.stimulus')
            o.hNoise.CloseUp();
        end
    end
   
    function generate_trialsList(o,S,P)
            % Call a function outside class (easier for us to edit)
            o.trialsList = [];  %all random for this one
    end
        
    %******** given an item number, reset the probe location, ori, and
    %******** its texture for future graphics
    function reset_probe_location_and_texture(o,firstime)
        %******** store target info (will need memory for PR struct)
        oldPos = o.PosList;
        if (firstime)
          anga = 2 * pi * rand;
          newvec = [cos(anga) sin(anga)];
        else
          newvec = -oldPos / norm(oldPos);  %unit vector away from old loc
          anga = -(pi/2) + (pi*rand);
          newvec = [[cos(anga) sin(anga)];[-sin(anga) cos(anga)]] * newvec';
        end
        o.PosList(1) = newvec(1) * o.P.stimEcc;
        o.PosList(2) = newvec(2) * o.P.stimEcc; 
        %******** try using moving targets (more interesting for animal?)
        oldvec = o.PosList - oldPos;
        newvec = oldvec / norm(oldvec);
        anga = -(pi/2) + (pi*rand);  % bias to be moving away from current loc
        newvec = [[cos(anga) sin(anga)];[-sin(anga) cos(anga)]] * newvec';
        o.MovList(1) = newvec(1) * o.MovStep;
        o.MovList(2) = newvec(2) * o.MovStep;
        %*****
        o.FixTime = 0;   % either zero, or time first fixated
        if o.oriNum > 2
          o.targOri = randi((o.oriNum-1));   % integer of ori, 1 to orinum
        else
          o.targOri = randi(o.oriNum);
        end
        o.hProbe{o.targOri}.position = [(o.S.centerPix(1) + round(o.PosList(1)*o.S.pixPerDeg)),...
                                        (o.S.centerPix(2) - round(o.PosList(2)*o.S.pixPerDeg))];
        %**************
    end
    
    function P = next_trial(o,S,P)
          %********************
          o.S = S;
          o.P = P;
          o.error = 0;
          o.FrameCount = 0;
          o.PFrameCount = 0;
          o.Flashtime = [];
          %********
          if (P.trialdur < 20)
              o.TrialDur = P.trialdur;
          else
              o.TrialDur = 20;
          end
          %*************
          o.FixCount = 0;
          o.FixMax = floor( o.TrialDur * 3 );
          o.FixHit = nan(2,o.FixMax);
          %***********
          o.rewardTime = 0;
          o.rewardGap = 0;
          %*******************
          
          % Make Gabor stimulus textures and position them somewhere random
          o.PosList = zeros(1,2); 
          o.MovList = zeros(1,2); 
          o.MovStep = (o.P.stimSpeed / o.S.frameRate);  % in degs for now
          o.FixTime = 0; 
          %********* location and orientation specific params
          o.reset_probe_location_and_texture(1)
    end
    
    function [FP,TS] = prep_run_trial(o)
            % Flags that control transitions
            % State is the main variable to control transitions. A protocol can be
            % described by shifting through states. For this protocol:
            % State 0 -- Foraging for targets
            % State 1 -- Fixation entered on target
            % State 2 -- Rewards for target, face shown
            % State 3 -- Foraging finished
            o.state = 0;
            % Errors describe why a trial was not completed
            % No possible errors for this type of experiment
            o.error = 0;
            % rewardCount counts the number of juice pulses, 1 delivered per frame
            o.rewardCount = 0;
            
            
            if isa(o.hNoise, 'stimuli.stimulus')
                
                if isprop(o.hNoise, 'probBlank')
                    o.hNoise.probBlank = 1-o.P.probNoise;
                end
                
                if isprop(o.hNoise, 'contrast') && isfield(o.P, 'noiseContrast')
                    o.hNoise.contrast = o.P.noiseContrast;
                end
                
                o.hNoise.beforeTrial();
            end
            
            %******* Plot States Struct (show fix in blue for eye trace)
                      % any special plotting of states, 
                      % FP(1).states = 1:2; FP(1).col = 'b';
                      % would show states 1,2 in blue for eye trace
            FP(1).states = 1;  %before fixation
            FP(1).col = 'b-';
            FP(2).states = 2;  % fixation held
            FP(2).col = 'r';
            FP(3).states = 3;  % reward on target  
            FP(3).col = 'g';
            %***********
            TS = 1:3;  % most states are time sensitive due to revcor
            %****************
            o.startTime = GetSecs;
            o.Iti = o.P.iti;  % default ITI, could be longer if error        
    end
    
    function updateNoise(o,xx,yy,currentTime)
         if (o.FrameCount < o.MaxFrame)
             
             switch o.noisetype
                 
                 case 1 % "Hartley" noise
                     
                     o.hNoise.afterFrame(); % update parameters
                     if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                         Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                         o.hNoise.beforeFrame(); % draw
                         Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                         o.hNoise.beforeFrame(); % draw
                     else
                        o.hNoise.beforeFrame(); % draw
                     end
                     %**********
                     o.FrameCount = o.FrameCount + 1;
                     % NOTE: store screen time in "continue_run_trial" after flip
                     o.NoiseHistory(o.FrameCount,2) = o.hNoise.orientation;  % store orientation
                     o.NoiseHistory(o.FrameCount,3) = o.hNoise.cpd;  % store spatialfrequency
                     
                     
                 case 2 % spatial reverse correlation
                     %******** select random locations in noise circle and draw
                     nlist = zeros(1,2*o.noiseNum);
                     for kk = 1:o.noiseNum
                         sx = (rand - 0.5) * 2 * o.P.snoisewidth;
                         sy = (rand - 0.5) * 2 * o.P.snoiseheight;
                         nlist(1,1+(kk-1)*2) = sx;
                         nlist(1,2+(kk-1)*2) = sy;
                         %*********
                         % o.hNoise{kk}.position = [(o.S.centerPix(1) + round(sx*o.S.pixPerDeg)),...
                         %                         (o.S.centerPix(2) - round(sy*o.S.pixPerDeg))];
                         % o.hNoise{kk}.beforeFrame();
                         %***********
                         if mod((kk-1),2)
                             col = 127 - o.P.range;
                         else
                             col = 127 + o.P.range;
                         end
                         position = [(o.S.centerPix(1) + round(sx*o.S.pixPerDeg)),...
                             (o.S.centerPix(2) - round(sy*o.S.pixPerDeg))];
                         r = round((o.P.snoisediam/2)*o.S.pixPerDeg);
                         rect = kron([1,1],position) + kron(r(:),[-1, -1, +1, +1]);
                         Screen('FillOval',o.winPtr,[col,col,col],rect');
                         %**************
                     end
                     %*********
                     o.FrameCount = o.FrameCount + 1;
                     o.NoiseHistory(o.FrameCount,:) = [NaN nlist];  % first element time, others x,y positions
                     %**********
                     
                 case 3 % CSD
                     kk = 0;
                     step = mod(o.FrameCount,(o.P.noisedur + o.P.noiseoff));
                     if (step >= o.P.noiseoff)
                         kk = 1;
                         Screen('FillRect', o.winPtr, 127 + o.P.noiserange);
                     else
                         Screen('FillRect', o.winPtr, 127);
                     end
                     %**********
                     o.FrameCount = o.FrameCount + 1;
                     % NOTE: store screen time in "continue_run_trial" after flip
                     o.NoiseHistory(o.FrameCount,2) = kk;  % store orientation number
                     %**********
                 
                 case 4 % "Garborium" noise
                     
                     o.hNoise.afterFrame(); % update parameters
                     if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                         Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                         o.hNoise.beforeFrame(); % draw
                         Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                         o.hNoise.beforeFrame(); % draw
                     else
                        o.hNoise.beforeFrame(); % draw
                     end
                     %**********
                     o.FrameCount = o.FrameCount + 1;
                     % NOTE: store screen time in "continue_run_trial" after flip
                     o.NoiseHistory(o.FrameCount,2) = o.hNoise.x(1);  % xposition of first gabor
                     o.NoiseHistory(o.FrameCount,3) = o.hNoise.mypars(2);  
                     
                 case 5 % dot spatial noise
                     o.hNoise.afterFrame(); % update parameters
                     if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                         Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                         o.hNoise.beforeFrame(); % draw
                         Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                         o.hNoise.beforeFrame(); % draw
                     else
                        o.hNoise.beforeFrame(); % draw
                     end
                     %**********
                     o.FrameCount = o.FrameCount + 1;
                     % NOTE: store screen time in "continue_run_trial" after flip
                     o.NoiseHistory(o.FrameCount,2:end) = [o.hNoise.x(1:o.noiseNum) o.hNoise.y(1:o.noiseNum)];  % xposition of first gabor
                 
                 case 6 % drifting gratings
                     
                     o.hNoise.afterFrame(); % update parameters
                     if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                         Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                         o.hNoise.beforeFrame(); % draw
                         Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                         o.hNoise.beforeFrame(); % draw
                     else
                        o.hNoise.beforeFrame(); % draw
                     end
                     %**********
                     o.FrameCount = o.FrameCount + 1;
                     % NOTE: store screen time in "continue_run_trial" after flip
                     o.NoiseHistory(o.FrameCount,2) = o.hNoise.orientation;  % store orientation
                     o.NoiseHistory(o.FrameCount,3) = o.hNoise.cpd;  % store spatialfrequency
                     o.NoiseHistory(o.FrameCount,4) = o.hNoise.phase;
                     o.NoiseHistory(o.FrameCount,5) = o.hNoise.orientation-90;
                     o.NoiseHistory(o.FrameCount,6) = o.hNoise.speed;
                     o.NoiseHistory(o.FrameCount,7) = o.hNoise.contrast;
                     
                     % time, orientation, cpd, phase, direction, speed, contrast

                 case 7% Denser "Garborium" noise
                     
                     o.hNoise.afterFrame(); % update parameters
                     o.hNoise.beforeFrame(); % draw
                     
                     %**********
                     o.FrameCount = o.FrameCount + 1;
                     % NOTE: store screen time in "continue_run_trial" after flip
                     o.NoiseHistory(o.FrameCount,2) = o.hNoise.x(1);  % xposition of first gabor
                     o.NoiseHistory(o.FrameCount,3) = o.hNoise.mypars(2);  

                  case 8
                     o.hNoise.frameUpdate=0;
                     o.hNoise.afterFrame(); % update parameters
                     %o.hNoise.afterFrame(); % update parameters
                     if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                         Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                         o.hNoise.beforeFrame(); % draw
                         Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                         o.hNoise.beforeFrame(); % draw
                     else
                        o.hNoise.beforeFrame(); % draw
                     end
                     %**********
                     o.FrameCount = o.FrameCount + 1;
                     for gr=1:4
                         % NOTE: store screen time in "continue_run_trial" after flip
                         o.NoiseHistory(o.FrameCount,2+(gr-1)*6) = o.hNoise.(['hNoise' num2str(gr)]).orientation;  % store orientation
                         o.NoiseHistory(o.FrameCount,3+(gr-1)*6) = o.hNoise.(['hNoise' num2str(gr)]).cpd;  % store spatialfrequency
                         o.NoiseHistory(o.FrameCount,4+(gr-1)*6) = o.hNoise.(['hNoise' num2str(gr)]).phase;
                         o.NoiseHistory(o.FrameCount,5+(gr-1)*6) = o.hNoise.(['hNoise' num2str(gr)]).orientation-90;
                         o.NoiseHistory(o.FrameCount,6+(gr-1)*6) = o.hNoise.(['hNoise' num2str(gr)]).speed;
                         o.NoiseHistory(o.FrameCount,7+(gr-1)*6) = o.hNoise.(['hNoise' num2str(gr)]).contrast;
                         
                         % time, orientation, cpd, phase, direction, speed, contrast
                     end

                   case 9
                     %o.hNoise.frameUpdate=0;
                     o.hNoise.afterFrame(); % update parameters
                     %o.hNoise.afterFrame(); % update parameters
                     if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                         Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                         o.hNoise.beforeFrame(); % draw
                         Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                         o.hNoise.beforeFrame(); % draw
                     else
                        o.hNoise.beforeFrame(); % draw
                     end
                     %**********
                     o.FrameCount = o.FrameCount + 1;
                     for gr=1:2
                         % NOTE: store screen time in "continue_run_trial" after flip
                         o.NoiseHistory(o.FrameCount,2+(gr-1)*6) = o.hNoise.(['hNoise' num2str(gr)]).orientation;  % store orientation
                         o.NoiseHistory(o.FrameCount,3+(gr-1)*6) = o.hNoise.(['hNoise' num2str(gr)]).cpd;  % store spatialfrequency
                         o.NoiseHistory(o.FrameCount,4+(gr-1)*6) = o.hNoise.(['hNoise' num2str(gr)]).phase;
                         o.NoiseHistory(o.FrameCount,5+(gr-1)*6) = o.hNoise.(['hNoise' num2str(gr)]).orientation-90;
                         o.NoiseHistory(o.FrameCount,6+(gr-1)*6) = o.hNoise.(['hNoise' num2str(gr)]).speed;
                         o.NoiseHistory(o.FrameCount,7+(gr-1)*6) = o.hNoise.(['hNoise' num2str(gr)]).contrast;
                         
                         % time, orientation, cpd, phase, direction, speed, contrast
                     end

                    case 10 % drifting gratings with indep TF
                     
                     o.hNoise.afterFrame(); % update parameters
                     if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                         Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                         o.hNoise.beforeFrame(); % draw
                         Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                         o.hNoise.beforeFrame(); % draw
                     else
                        o.hNoise.beforeFrame(); % draw
                     end
                     %**********
                     o.FrameCount = o.FrameCount + 1;
                     % NOTE: store screen time in "continue_run_trial" after flip
                     o.NoiseHistory(o.FrameCount,2) = o.hNoise.orientation;  % store orientation
                     o.NoiseHistory(o.FrameCount,3) = o.hNoise.cpd;  % store spatialfrequency
                     o.NoiseHistory(o.FrameCount,4) = o.hNoise.phase;
                     o.NoiseHistory(o.FrameCount,5) = o.hNoise.orientation-90;
                     o.NoiseHistory(o.FrameCount,6) = o.hNoise.tf;
                     o.NoiseHistory(o.FrameCount,7) = o.hNoise.contrast;
                     
                     % time, orientation, cpd, phase, direction, tf, contrast
                    case 11 % drifting gratings with indep TF
                     
                     o.hNoise.afterFrame(); % update parameters
                     if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                         Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                         o.hNoise.beforeFrame(); % draw
                         Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                         o.hNoise.beforeFrame(); % draw
                     else
                        o.hNoise.beforeFrame(); % draw
                     end
                     %**********
                     o.FrameCount = o.FrameCount + 1;
                     % NOTE: store screen time in "continue_run_trial" after flip
                     o.NoiseHistory(o.FrameCount,2) = o.hNoise.orientation;  % store orientation
                     o.NoiseHistory(o.FrameCount,3) = o.hNoise.cpd;  % store spatialfrequency
                     o.NoiseHistory(o.FrameCount,4) = o.hNoise.phase;
                     o.NoiseHistory(o.FrameCount,5) = o.hNoise.orientation-90;
                     o.NoiseHistory(o.FrameCount,6) = o.hNoise.tf;
                     o.NoiseHistory(o.FrameCount,7) = o.hNoise.contrast;

                     % time, orientation, cpd, phase, direction, tf, contrast
                 case 14 % Full-field static hartleyplaid (tight rectangular grid)
                     o.hNoise.afterFrame();       % update internal counters
                     if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                         Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                         o.hNoise.beforeFrame();  % draw (eye 0)
                         Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                         o.hNoise.beforeFrame();  % draw (eye 1)
                     else
                         o.hNoise.beforeFrame();  % draw mono
                     end

                     o.FrameCount = o.FrameCount + 1;

                     % Current parameters
                     nK  = o.hNoise.K;
                     amp = o.hNoise.current.amp(:);   % signed amplitudes
                     fx  = o.hNoise.current.fx(:);
                     fy  = o.hNoise.current.fy(:);
                     idx = o.hNoise.current.idx(:);

                     % Build log row: [K | fx(1:K) | fy(1:K) | amp(1:K) | idx(1:K)]
                     row = [nK, fx.', fy.', amp.', double(idx.')];

                     % Write to NoiseHistory (col 1 = time, set after Flip)
                     o.NoiseHistory(o.FrameCount, 2:(1+numel(row))) = row;

                 case 15 % Random-phase Fourier hyperplaid
                     o.hNoise.afterFrame();
                     if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                         Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                         o.hNoise.beforeFrame();
                         Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                         o.hNoise.beforeFrame();
                     else
                         o.hNoise.beforeFrame();
                     end

                     o.FrameCount = o.FrameCount + 1;
                     row = o.hNoise.currentLogRowNumeric(NaN);
                     % Timestamp is written after Flip; copy the remainder.
                     o.NoiseHistory(o.FrameCount, 2:numel(row)) = row(2:end);


                     
             end
            %****************
         end
    end    
    
    function [drop,faceitem] = updateProbes(o,xx,yy,currentTime)
        %**********
        drop = 0;  % none were fixated
        faceitem = 0; % default, none are rewarded
        %***********
        if (o.state > 0)
            %******* if motion, update probe position
            if (o.MovStep > 0)
                newPos = o.PosList + o.MovList;
                if (abs(newPos(1)) > o.P.stimBound)
                      o.MovList(1) = -o.MovList(1); 
                end
                if (abs(newPos(2)) > o.P.stimBound)
                      o.MovList(2) = -o.MovList(2);
                end
                o.PosList = newPos;
                %****** recompute position in pixel coordinates
                o.hProbe{o.targOri}.position = [(o.S.centerPix(1) + round(newPos(1)*o.S.pixPerDeg)),...
                                                (o.S.centerPix(2) - round(newPos(2)*o.S.pixPerDeg))];
                if (o.state == 3)
                    o.Faces.position = o.hProbe{o.targOri}.position;
                end
                %***************************
            end
        end
        if (o.state == 1)  % if state == 2 or 3, then no stim visible to check
            %**********************************************************
            itfix = 0;
            %****** determine if item is fixated
            dist = norm( o.PosList - [xx,yy]);
            if (dist < o.P.fixRadius)
               itfix = 1;
               %****** change probe to be Gaussian, indicate it is fixated
               if (o.FixTime == 0)
                 o.hProbe{o.oriNum}.position = o.hProbe{o.targOri}.position;
                 o.targOri = o.oriNum;
               end
               %*****
            else
               %****** check if hold on item is broken, if so jump new targ
               if ( o.FixTime > 0)
                      %**********
                      o.reset_probe_location_and_texture(0); % make it jump, firstime=1
                      o.FixTime = 0;  % reset, they broke fixation
                      %**********
               end
               %***************
            end
            %****** if an item is fixated, do something
            if (itfix > 0)
                if ~o.FixTime  %first detection, set the time
                    o.FixTime = currentTime;
                else
                   if ( (currentTime - o.FixTime) > o.P.holdDur )
                         drop = 1;  % give reward
                         faceitem = itfix;  %run face stimulus indep of probe
                         %**** record where the fixation occured for eye display
                         if (o.FixCount < o.FixMax)
                             o.FixCount = o.FixCount + 1;
                             o.FixHit(:,o.FixCount) = o.PosList;
                         end
                         %**************
                         o.Faces.imagenum = randi(length(o.Faces.tex));  % pick any at random
                         o.Faces.position = o.hProbe{o.targOri}.position; % set at face at target 
                         %**********
                         o.reset_probe_location_and_texture(0); % make it jump, firstime=1
                         o.FixTime = 0;  % reset item to zero
                         %***********
                   end
                end
            end
        end
        %****** store probe information
        if (o.PFrameCount < o.MaxFrame)
            o.PFrameCount = o.PFrameCount + 1;
            if (drop == 1)  % will be moving to state 2 or 3
                   o.ProbeHistory(o.PFrameCount,1) = NaN;
                   o.ProbeHistory(o.PFrameCount,2) = NaN;
                   o.ProbeHistory(o.PFrameCount,3) = 0;  % intermediate at drop          
            else
                if (o.state < 2)
                   o.ProbeHistory(o.PFrameCount,1) = o.PosList(1);
                   o.ProbeHistory(o.PFrameCount,2) = o.PosList(2);
                   o.ProbeHistory(o.PFrameCount,3) = o.targOri;
                else
                   if (o.state == 3)
                      o.ProbeHistory(o.PFrameCount,1) = NaN;
                      o.ProbeHistory(o.PFrameCount,2) = NaN;
                      o.ProbeHistory(o.PFrameCount,3) = -o.Faces.imagenum;   %indicates face
                   else
                      o.ProbeHistory(o.PFrameCount,1) = NaN;  % not being shown
                      o.ProbeHistory(o.PFrameCount,2) = NaN;
                      o.ProbeHistory(o.PFrameCount,3) = NaN; 
                   end
                end
            end
            % NOTE: store screen time in "continue_run_trial" after flip
        end
        %*******************************
    end
    
    function keepgoing = continue_run_trial(o,screenTime)
        keepgoing = 0;
        if (o.state < 4)
            keepgoing = 1;
        end
        %******** this is also called post-screen flip, and thus
        %******** can be used to time-stamp any previous graphics calls
        %******** for object on the screen and things like that
        if (o.FrameCount)
           o.NoiseHistory(o.FrameCount,1) = screenTime;  %store screen flip 
        end
        if (o.PFrameCount)
           o.ProbeHistory(o.PFrameCount,4) = screenTime;     
        end
        %******************************************************
    end
   
    %******************** THIS IS THE BIG FUNCTION *************
    function drop = state_and_screen_update(o,currentTime,x,y, varargin) 
         outputs = {};
         if ~isempty(varargin)
             inputs=varargin{1};
             if length(varargin)>1
                outputs=varargin{2};
             end
         end

        drop = 0; % initialize
        
        %******* THIS PART CHANGES WITH EACH PROTOCOL ****************
        if (o.state == 0)
            o.state = 1;  % jump in and plot eye traces
        end
        if currentTime > o.startTime + o.TrialDur
            o.state = 4;  % time to end trial
            o.itiStart = GetSecs;
            if isa(o.hNoise, 'stimuli.hartleyplaid_procedural') && ...
                    isprop(o.hNoise, 'oldmaximumvalue') && ...
                    isprop(o.hNoise, 'oldclampcolors') && ...
                    isprop(o.hNoise, 'oldapplyToDoubleInputMakeTexture') && ...
                    ~isempty(o.hNoise.oldmaximumvalue)
                try
                    Screen('ColorRange', o.hNoise.winPtr, o.hNoise.oldmaximumvalue, ...
                        o.hNoise.oldclampcolors, o.hNoise.oldapplyToDoubleInputMakeTexture);
                catch
                end
            end
            return
        end
        %***********************
        
        % ALWAYS UPDATE BACKGROUND
        o.updateNoise(NaN,NaN,currentTime);
        
        % ALWAYS UPDATE THE PROBES
        [drop,faceitem] = o.updateProbes(x,y,currentTime); %#ok<ASGLU>
        
        %****** update state by reward events
        if (drop)
            o.rewardTime = currentTime;
            rn = rand;
            o.rewardGap = o.P.mingap + rn * (o.P.maxgap - o.P.mingap);
            if (rn > (1-o.P.probFace))
                o.state = 3;
                if (o.faceTime > o.rewardGap)
                    o.rewardGap = o.faceTime;
                end
            else
                o.state = 2;  % move to a period with no probe target
            end
        end
        %********* update state based on reward timing
        if (o.rewardTime > 0)
            if ( (currentTime - o.rewardTime) > o.rewardGap)
                o.rewardTime = 0;
                o.state = 1;  % show stim again
            else
                if (o.state == 3)  
                    if ( (currentTime - o.rewardTime) > o.faceTime)
                        o.state = 2;  % stop showing face, give extra juice
                        drop = 1;
                    end
                end
            end
        end
        %*******ACTUAL DRAWING OF THE STIMULI *************
        % Draw probe stimuli
        if (o.state < 2)
            if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                o.hProbe{o.targOri}.beforeFrame();  % only one target now
                Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                o.hProbe{o.targOri}.beforeFrame();  % only one target now
            else
                o.hProbe{o.targOri}.beforeFrame();  % only one target now
            end
        end
        % Draw face stimulus at probe location and reward at end of display
        if (o.state == 3) 
            if isfield(o.S,'stereoMode') && o.S.stereoMode>0
                Screen('SelectStereoDrawBuffer', o.winPtr, 0);
                o.Faces.beforeFrame();
                Screen('SelectStereoDrawBuffer', o.winPtr, 1);
                o.Faces.beforeFrame();
            else
                o.Faces.beforeFrame();
            end
        end
        %****************************************   
        
%         Screen('DrawingFinished', o.winPtr);


        o.Flashtime = marmoview.updatePhotodiode(o.winPtr,o.S,outputs,o.FrameCount,currentTime,o.Flashtime);
    end
    
    function Iti = end_run_trial(o)
        Iti = o.Iti - (GetSecs - o.itiStart); % returns generic Iti interval
    end
    
    function plot_trace(o,handles)
        %****** plot eccentric ring where stimuli appear
        h = handles.EyeTrace;
        set(h,'NextPlot','Replace');
        eyeRad = handles.eyeTraceRadius;
        % Target ring
        r = o.P.stimEcc;
        plot(h,r*cos(0:.01:1*2*pi),r*sin(0:.01:1*2*pi),'-k');
        set(h,'NextPlot','Add');
        %********** plot where all target hits occured
        for k = 1:o.FixCount
           r = o.P.fixRadius;
           xx = o.FixHit(1,k);
           yy = o.FixHit(2,k);
           plot(h,xx + r*cos(0:.01:1*2*pi),yy + r*sin(0:.01:1*2*pi),'-m');
        end
        %*****************
        axis(h,[-eyeRad eyeRad -eyeRad eyeRad]);
    end
    
    function PR = end_plots(o,P,A)   %update D struct if passing back info
        
        %************* STORE DATA to PR
        %**** NOTE, no need to copy anything from P itself, that is saved
        %**** already on each trial in data .... copy parts that are not
        %**** reflected in P at all and generated random per trial
        PR = struct;
        if isa(o.hNoise, 'stimuli.stimulus')
            PR.hNoise = copy(o.hNoise); % store noise object
            if isa(o.hNoise, 'stimuli.fourierplaid_procedural')
                PR.hNoise.bank = []; % lattice is fixed and large
                PR.NoiseHistorySchema = o.hNoise.schemaVersion;
                PR.NoiseHistoryFields = { ...
                    'time', 'K', 'fx', 'fy', 'phaseRad', ...
                    'amplitude', 'bankIndex'};
                PR.FourierPhaseConvention = o.hNoise.phaseConvention;
                PR.FourierRngSeed = o.hNoise.trialSeed;
                PR.FourierRngInitialState = o.hNoise.trialInitialState;
                PR.FourierBankMode = o.hNoise.bankMode;
                PR.FourierBankDefinitionVersion = ...
                    o.hNoise.bankDefinitionVersion;
                PR.FourierBankInfo = o.hNoise.spiralBankInfo;
            elseif isa(o.hNoise, 'stimuli.hartleyplaid_procedural')
                PR.hNoise.bank = []; %too big to store everything on every trial. (not unique to trials)
            end
        end


        
        PR.error = o.error;
        if o.FrameCount == 0
            PR.NoiseHistory = [];
            PR.ProbeHistory = [];
        else
            PR.NoiseHistory = o.NoiseHistory(1:o.FrameCount,:);
            PR.ProbeHistory = o.ProbeHistory(1:o.PFrameCount,:);
        end
        PR.spatoris = o.spatoris;  % constant over trials, but still nice to store
        PR.spatfreqs = o.spatfreqs; % constant, but I want to store them
        PR.noisetype = o.noisetype; % store just in case (have in P also)
        PR.noiseNum = o.noiseNum; %differs based on noise type
        %******* need to add a History for probe stimuli later
        
        PR.Flashtime = o.Flashtime;
        %******* this is also where you could store Gabor Flash Info
        
        %%%% Record some data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% It is advised not to store things too large here, like eye movements, 
        %%%% that would be very inefficient as the experiment progresses
        o.D.error(A.j) = o.error;   % need to decide on something later
        
        %%%% Plot results %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Nothing for now ...
       
    end
    
  end % methods
  
  methods (Static)
      
      function [Probe, Faces] = regenerateProbes(P,S,winPtr)
          %******* init reward face for correct trials
          if ~exist('winPtr', 'var')
              winPtr = 0;
          end
          
          Faces = stimuli.gaussimages(winPtr,'bkgd',S.bgColour,'gray',false);   % color images
          Faces.loadimages('MarmosetFaceLibrary.mat');
          Faces.position = [0,0]*S.pixPerDeg + S.centerPix;
          Faces.radius = round(P.faceradius*S.pixPerDeg);
          Faces.imagenum = 1;  % start first face
          Faces.transparency = -1;  % blend into background
          
          %***** create a Gabor target grating
          oriNum = P.orinum;
          Probe = cell(1,oriNum);
          for kk = 1:oriNum
              %*******
              Probe{kk} = stimuli.grating(winPtr);  % grating probe
              Probe{kk}.transparent = -P.probecon;  % blend in proportion to gauss
              Probe{kk}.gauss = true;
              Probe{kk}.pixperdeg = S.pixPerDeg;
              Probe{kk}.radius = round(P.proberadius*S.pixPerDeg);
              
              Probe{kk}.range = P.proberange;
              Probe{kk}.square = false;
              Probe{kk}.bkgd = P.bkgd;
              %**************
              Probe{kk}.position = [S.centerPix(1),S.centerPix(2)];
              Probe{kk}.phase = P.phase;
              Probe{kk}.cpd = P.cpd;
              if (kk < oriNum)
                  if (kk == 1)
                      Probe{kk}.orientation = P.prefori;
                  else
                      Probe{kk}.orientation = P.nonprefori;
                      Probe{kk}.cpd = P.noncpd;
                  end
                  
              else
                  Probe{kk}.orientation = 0;
                  Probe{kk}.cpd = 0;
                  Probe{kk}.phase = 0;
              end
              %**************
              Probe{kk}.updateTextures();
              %****************
          end
          
          
      end
  end
    
end % classdef
