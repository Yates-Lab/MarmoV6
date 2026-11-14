function selection = optimizeMarmosetBackground(calibration,options)
% OPTIMIZEMARMOSETBACKGROUND Background maximizing the matched null contrast.
%
% selection = marmoview.optimizeMarmosetBackground(calibration,options)
%
% calibration is a struct returned by marmoview.loadCandidateConeCalibration.
% Pigment-null RGB directions do not depend on the background, but their
% Weber contrast does: lowering the background excitation of the ML cones
% (mostly the green primary) raises the contrast every null can reach.
% The grid search maximizes the smallest, over the null axes, of each
% axis's largest symmetric non-silenced ML contrast, subject to a minimum
% background luminance (rod saturation) and channel bounds (reliable gamma).
%
% Quantization matters as much as gamut: a dim primary makes one device
% code a large Weber step for the cones it drives (a low blue background
% inflates S-cone leakage). Candidates are therefore taken in order of
% matched contrast, and the first whose quantized null endpoints (at
% MatchedContrastFraction of its limit) keep the silent pigments within
% LeakageSafetyFactor times both leakage tolerances is selected.
%
% Options:
%   MinimumLuminanceCdM2      Background luminance floor (60)
%   ChannelBounds             Linear RGB bounds for each channel ([0.1 0.9])
%   StepSize                  Grid step in linear RGB (0.01)
%   NullPeaksNm               Axes to match ([543 556 563])
%   FixedBackgroundLinearRGB  Evaluate only this background ([])
%   MatchedContrastFraction   Fraction of the limit that will be used (0.95)
%   SilentLeakageTolerance    Absolute realized leakage limit (0.005)
%   RelativeLeakageTolerance  Leakage / realized signal limit (0.10)
%   LeakageSafetyFactor       Margin applied to both limits (0.8)
%   MaximumCandidatesChecked  Quantization checks before giving up (20000)
%   AchromaticContrastScale   Largest achromatic contrast / matched contrast;
%                             b*(1 +/- that contrast) must stay in gamut (1)

if nargin < 2 || isempty(options)
    options = struct();
end
options = setDefault(options,'MinimumLuminanceCdM2',60);
options = setDefault(options,'ChannelBounds',[0.1 0.9]);
options = setDefault(options,'StepSize',0.01);
options = setDefault(options,'NullPeaksNm',[543 556 563]);
options = setDefault(options,'FixedBackgroundLinearRGB',[]);
options = setDefault(options,'MatchedContrastFraction',0.95);
options = setDefault(options,'SilentLeakageTolerance',0.005);
options = setDefault(options,'RelativeLeakageTolerance',0.10);
options = setDefault(options,'LeakageSafetyFactor',0.8);
options = setDefault(options,'MaximumCandidatesChecked',20000);
options = setDefault(options,'AchromaticContrastScale',1);

bounds = double(options.ChannelBounds);
if numel(bounds) ~= 2 || bounds(1) <= 0 || bounds(2) >= 1 || bounds(1) >= bounds(2)
    error('optimizeMarmosetBackground:Bounds', ...
        'ChannelBounds must satisfy 0 < lower < upper < 1.');
end
luminanceRow = calibration.PhotopicLuminanceCdM2PerLinearRGB(:)';
if options.MinimumLuminanceCdM2 > 0 && any(~isfinite(luminanceRow))
    error('optimizeMarmosetBackground:Luminance', ...
        'Calibration lacks absolute luminance; cannot apply a luminance floor.');
end

T = calibration.CandidateRGBToCones;
peaks = calibration.CandidateConePeaksNm(:)';
nulls = double(options.NullPeaksNm(:))';
sIndex = find(peaks == 423,1);
directions = zeros(3,numel(nulls));
mlMasks = false(4,numel(nulls));
silentRows = zeros(numel(nulls),2);
for k = 1:numel(nulls)
    silentRows(k,:) = [sIndex find(peaks == nulls(k),1)];
    directions(:,k) = null(T(silentRows(k,:),:));
    mlMasks(:,k) = (peaks ~= 423 & peaks ~= nulls(k))';
end

if isempty(options.FixedBackgroundLinearRGB)
    levels = bounds(1):options.StepSize:bounds(2);
    [R,G,B] = ndgrid(levels,levels,levels);
    candidates = [R(:) G(:) B(:)]';
else
    candidates = double(options.FixedBackgroundLinearRGB(:));
end
perNull = axisContrast(candidates,T,directions,mlMasks);
matched = min(perNull,[],1);
luminance = luminanceRow*candidates;
feasible = find(luminance >= options.MinimumLuminanceCdM2 - 1e-9);
if isempty(feasible)
    error('optimizeMarmosetBackground:Infeasible', ...
        'No background within the channel bounds reaches %.3g cd/m2.', ...
        options.MinimumLuminanceCdM2);
end
achromaticHeadroom = min((1-candidates)./candidates,[],1);
achromaticNeed = options.AchromaticContrastScale* ...
    options.MatchedContrastFraction*matched;
feasible = feasible(achromaticHeadroom(feasible) >= achromaticNeed(feasible));
if isempty(feasible)
    error('optimizeMarmosetBackground:AchromaticGamut', ...
        'No background leaves gamut headroom for the matched achromatic field.');
end
[~,order] = sort(matched(feasible),'descend');
feasible = feasible(order);

absoluteLimit = options.LeakageSafetyFactor*options.SilentLeakageTolerance;
relativeLimit = options.LeakageSafetyFactor*options.RelativeLeakageTolerance;
bestIndex = [];
checked = 0;
for index = feasible
    checked = checked+1;
    if checked > options.MaximumCandidatesChecked
        break
    end
    [absoluteLeak,relativeLeak] = quantizedLeakage(calibration, ...
        candidates(:,index),options.MatchedContrastFraction*matched(index), ...
        T,directions,mlMasks,silentRows);
    if absoluteLeak <= absoluteLimit && relativeLeak <= relativeLimit
        bestIndex = index;
        break
    end
end
if isempty(bestIndex)
    error('optimizeMarmosetBackground:Leakage', ...
        ['No background meeting %.3g cd/m2 keeps quantized silent-pigment ' ...
        'leakage within tolerance at %d bits.'],options.MinimumLuminanceCdM2, ...
        calibration.BitDepth);
end
background = candidates(:,bestIndex);
[absoluteLeak,relativeLeak] = quantizedLeakage(calibration,background, ...
    options.MatchedContrastFraction*matched(bestIndex),T,directions,mlMasks,silentRows);

reference = calibration.ExportedBackgroundLinearRGB(:);
selection = struct();
selection.BackgroundLinearRGB = background';
selection.BackgroundLuminanceCdM2 = luminanceRow*background;
selection.MatchedContrastLimit = matched(bestIndex);
selection.PerNullContrastLimit = perNull(:,bestIndex)';
selection.NullPeaksNm = nulls;
selection.PredictedSilentLeakage = absoluteLeak;
selection.PredictedRelativeLeakage = relativeLeak;
selection.CandidatesChecked = checked;
selection.UnconstrainedMatchedContrastLimit = matched(feasible(1));
selection.ReferenceBackgroundLinearRGB = reference';
selection.ReferenceLuminanceCdM2 = luminanceRow*reference;
selection.ReferencePerNullContrastLimit = ...
    axisContrast(reference,T,directions,mlMasks)';
selection.ReferenceMatchedContrastLimit = ...
    min(selection.ReferencePerNullContrastLimit);
selection.Options = options;
end


function contrast = axisContrast(backgrounds,T,directions,mlMasks)
excitation = T*backgrounds;
contrast = zeros(size(directions,2),size(backgrounds,2));
for k = 1:size(directions,2)
    d = directions(:,k);
    active = abs(d) > 1e-14;
    limit = min(min(backgrounds(active,:),1-backgrounds(active,:)) ./ ...
        abs(d(active)),[],1);
    unit = abs(T*d)./excitation;
    contrast(k,:) = limit.*max(unit(mlMasks(:,k),:),[],1);
end
end


function [absoluteLeak,relativeLeak] = quantizedLeakage(calibration,b, ...
        target,T,directions,mlMasks,silentRows)
% Worst silent-pigment leakage over the null endpoints after quantization.
calibration.BackgroundLinearRGB = b';
absoluteLeak = 0;
relativeLeak = 0;
e0 = T*b;
for k = 1:size(directions,2)
    d = directions(:,k);
    d = d/max(abs(T(mlMasks(:,k),:)*d)./e0(mlMasks(:,k)));
    endpoints = min(max([b b-target*d b+target*d],0),1);
    realized = marmoview.realizeCalibratedRGB(calibration,endpoints');
    linear = realized.RealizedLinearRGB';
    excitation = T*linear;
    contrast = excitation(:,2:3)./excitation(:,1) - 1;
    leak = max(abs(contrast(silentRows(k,:),:)),[],'all');
    signal = min(max(abs(contrast(mlMasks(:,k),:)),[],1));
    absoluteLeak = max(absoluteLeak,leak);
    relativeLeak = max(relativeLeak,leak/max(eps,signal));
end
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
