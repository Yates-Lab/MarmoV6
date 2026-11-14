function results = simulate_fourierplaid_contrast(nFrames, seed)
%SIMULATEFOURIERPLAIDCONTRAST Check nominal linear-range excursions.
%   This samples all random-phase settings without opening a PTB
%   window. No clipping or per-frame normalization is applied. The output
%   reports the fraction that would lie outside the [0,1] framebuffer range.

if nargin < 1 || isempty(nFrames), nFrames = 1000; end
if nargin < 2 || isempty(seed), seed = 8675309; end

settingsNames = { ...
    'Forage_RandomPhaseHyperplaid', ...
    'Forage_RandomPhaseHyperplaid_Dense', ...
    'Forage_RandomPhaseHyperplaid_Isotropic', ...
    'Forage_RandomPhaseHyperplaid_Spiral', ...
    'Forage_RandomPhaseHyperplaid_Pminus1_4cpd_5648', ...
    'Forage_RandomPhaseHyperplaid_Pminus2_16cpd_2800'};
[u,v] = meshgrid(((1:128)-64.5)/128, -((1:72)-36.5)/72);
modeNames = {'random-phase Fourier','Hartley reference'};
results = repmat(struct, numel(modeNames), numel(settingsNames));

for iPreset = 1:numel(settingsNames)
    [S,P] = feval(settingsNames{iPreset});
    Wdeg = (S.screenRect(3)-S.screenRect(1))/S.pixPerDeg;
    Hdeg = (S.screenRect(4)-S.screenRect(2))/S.pixPerDeg;
    if isfield(P,'hp_spiralBank') && P.hp_spiralBank
        spiralMaxSF = P.hp_maxSF;
        if isfield(P,'hp_spiralMaxSF')
            spiralMaxSF = P.hp_spiralMaxSF;
        end
        spiralAxisCount = 0;
        if isfield(P,'hp_spiralAxisCount')
            spiralAxisCount = P.hp_spiralAxisCount;
        end
        [spiralBank,~] = stimuli.buildGoldenSpiralFourierBank( ...
            Wdeg,Hdeg,P.hp_spiralTargetCount,spiralMaxSF, ...
            P.hp_spiralDensityExponent,P.hp_spiralMinSF,spiralAxisCount);
        nAxes = numel(spiralBank)/2;
        KX = [spiralBank(1:nAxes).kx].';
        KY = [spiralBank(1:nAxes).ky].';
    else
        [sx,sy] = localStrides(Wdeg,Hdeg,P.hp_maxSF,P.hp_ns,P.equalStride);
        kxPositive = sx:sx:floor(Wdeg*P.hp_maxSF);
        kyPositive = sy:sy:floor(Hdeg*P.hp_maxSF);
        kxValues = [-kxPositive(end:-1:1), 0, kxPositive];
        kyValues = [-kyPositive(end:-1:1), 0, kyPositive];
        [KX,KY] = ndgrid(kxValues,kyValues);
        keep = (KX>0) | (KX==0 & KY>0);
        KX = KX(keep); KY = KY(keep);
    end

    componentAmplitude = P.noiseContrast/sqrt(P.hp_K);
    for iMode = 1:numel(modeNames)
        % Independent simulation streams; this does not imply synchronized
        % streams in the experiment implementation.
        stream = RandStream('mt19937ar','Seed',seed+100*iMode+iPreset-1);
        allValues = zeros(nFrames,numel(u),'single');
        for iFrame = 1:nFrames
            base = randperm(stream,numel(KX),P.hp_K);
            coordinateSign = 1-2*double(rand(stream,1,P.hp_K)>0.5);
            if iMode == 1
                phases = 2*pi*rand(stream,1,P.hp_K);
                amplitudeSign = ones(1,P.hp_K);
            else
                phases = -pi/4*ones(1,P.hp_K);
                amplitudeSign = 1-2*double(rand(stream,1,P.hp_K)>0.5);
            end
            deviation = zeros(size(u));
            for j = 1:P.hp_K
                theta = 2*pi*(coordinateSign(j)*KX(base(j))*u + ...
                    coordinateSign(j)*KY(base(j))*v) + phases(j);
                deviation = deviation + componentAmplitude* ...
                    amplitudeSign(j)*cos(theta);
            end
            allValues(iFrame,:) = single(0.5 + deviation(:));
        end

        sortedValues = sort(allValues(:));
        n = numel(sortedValues);
        results(iMode,iPreset).settings = settingsNames{iPreset};
        results(iMode,iPreset).mode = modeNames{iMode};
        results(iMode,iPreset).nFrames = nFrames;
        results(iMode,iPreset).componentAmplitude = componentAmplitude;
        results(iMode,iPreset).theoreticalPeakDeviation = ...
            P.noiseContrast*sqrt(P.hp_K);
        results(iMode,iPreset).minimum = double(sortedValues(1));
        results(iMode,iPreset).q001 = ...
            double(sortedValues(max(1,round(0.001*n))));
        results(iMode,iPreset).median = ...
            double(sortedValues(round(0.5*n)));
        results(iMode,iPreset).q999 = ...
            double(sortedValues(min(n,round(0.999*n))));
        results(iMode,iPreset).maximum = double(sortedValues(end));
        results(iMode,iPreset).outsideFraction = ...
            mean(allValues(:)<0 | allValues(:)>1);
        results(iMode,iPreset).rmsDeviation = ...
            sqrt(mean((double(allValues(:))-0.5).^2));

        fprintf('%s / %s: min %.4f, q.001 %.4f, q.999 %.4f, max %.4f, outside %.4f%%\n', ...
            settingsNames{iPreset}, modeNames{iMode}, ...
            results(iMode,iPreset).minimum, results(iMode,iPreset).q001, ...
            results(iMode,iPreset).q999, results(iMode,iPreset).maximum, ...
            100*results(iMode,iPreset).outsideFraction);
    end
end
end

function [sx,sy] = localStrides(Wdeg,Hdeg,maxSF,ns,equalStride)
KxMax = floor(Wdeg*maxSF);
KyMax = floor(Hdeg*maxSF);
if isinf(ns) || ns >= min(2*KxMax+1,2*KyMax+1)
    sx = 1; sy = 1;
    return
end
if ns < 3, ns = 3; elseif mod(ns,2)==0, ns = ns+1; end
m = (ns-1)/2;
sxCandidates = max(1,ceil(KxMax/(m+1))):max(1,floor(KxMax/m));
syCandidates = max(1,ceil(KyMax/(m+1))):max(1,floor(KyMax/m));
[sx,sy] = localBestPair(sxCandidates,syCandidates,Wdeg,Hdeg);
if equalStride
    step = min(2*maxSF/(ns-1),2*maxSF/(ns-1));
    sxTry = round(step*Wdeg); syTry = round(step*Hdeg);
    [sx,sy] = localBestPair(max(1,sxTry-1):sxTry+1, ...
        max(1,syTry-1):syTry+1,Wdeg,Hdeg);
end
end

function [sx,sy] = localBestPair(sxCandidates,syCandidates,Wdeg,Hdeg)
bestError = inf; sx = 1; sy = 1;
for sxCandidate = sxCandidates
    for syCandidate = syCandidates
        candidateError = abs(log((sxCandidate/Wdeg)/(syCandidate/Hdeg)));
        if candidateError < bestError
            bestError = candidateError;
            sx = sxCandidate; sy = syCandidate;
        end
    end
end
end
