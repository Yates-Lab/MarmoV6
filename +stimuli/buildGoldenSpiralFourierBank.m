function [bank, info] = buildGoldenSpiralFourierBank(Wdeg, Hdeg, targetCount, maxSF, densityExponent, minSF, desiredAxisCount)
% Build a canonical random-phase Fourier bank from a golden-angle proposal.
%
% Every continuous target is independently snapped to its genuinely nearest
% screen-periodic lattice coordinate. The result is then canonicalized under
% k <-> -k and deduplicated. Targets are never displaced to a farther lattice
% coordinate merely to enforce uniqueness.
%
% targetCount is the initial number of continuous proposals. If the optional
% desiredAxisCount is positive, proposal count is increased deterministically
% until at least that many unique physical axes exist; a small excess is
% removed at evenly spaced ranks to preserve the radial distribution.

validateattributes(Wdeg, {'numeric'}, {'scalar','real','finite','positive'});
validateattributes(Hdeg, {'numeric'}, {'scalar','real','finite','positive'});
validateattributes(targetCount, {'numeric'}, {'scalar','integer','positive'});
validateattributes(maxSF, {'numeric'}, {'scalar','real','finite','positive'});
if nargin < 5 || isempty(densityExponent), densityExponent = -1; end
if nargin < 6 || isempty(minSF), minSF = 0; end
if nargin < 7 || isempty(desiredAxisCount), desiredAxisCount = 0; end
validateattributes(densityExponent, {'numeric'}, ...
    {'scalar','real','finite','>=',-2});
validateattributes(minSF, {'numeric'}, ...
    {'scalar','real','finite','nonnegative','<',maxSF});
validateattributes(desiredAxisCount, {'numeric'}, ...
    {'scalar','integer','nonnegative'});

goldenAngle = pi * (3 - sqrt(5));
proposalCount = double(targetCount);
requestedAxes = double(desiredAxisCount);
maxAttempts = 12;

for attempt = 1:maxAttempts
    [canonicalK, firstOccurrence, snapError, minSFUsed, radialRule] = ...
        localSnapAndDeduplicate(Wdeg, Hdeg, proposalCount, maxSF, ...
        densityExponent, minSF, goldenAngle);
    uniqueBeforeSelection = size(canonicalK,1);
    if requestedAxes == 0 || uniqueBeforeSelection >= requestedAxes
        break
    end
    growth = max(1.15, 1.05 * requestedAxes / max(uniqueBeforeSelection,1));
    proposalCount = ceil(proposalCount * growth);
end

if requestedAxes > 0 && uniqueBeforeSelection < requestedAxes
    error('Could not produce %d unique axes after %d proposal expansions.', ...
        requestedAxes, maxAttempts);
end

if requestedAxes > 0 && uniqueBeforeSelection > requestedAxes
    selected = round(linspace(1, uniqueBeforeSelection, requestedAxes));
    canonicalK = canonicalK(selected,:);
    firstOccurrence = firstOccurrence(selected);
end

KXh = canonicalK(:,1);
KYh = canonicalK(:,2);
KXp = [KXh; -KXh];
KYp = [KYh; -KYh];
fx = KXp / Wdeg;
fy = KYp / Hdeg;
sf = hypot(fx, fy);
th = atan2(fy, fx);
nAxes = numel(KXh);
opp = [(nAxes+1):(2*nAxes), 1:nAxes].';
bank = struct('fx', num2cell(fx), ...
              'fy', num2cell(fy), ...
              'kx', num2cell(KXp), ...
              'ky', num2cell(KYp), ...
              'sf', num2cell(sf), ...
              'th', num2cell(th), ...
              'ori', num2cell(rad2deg(mod(th, 2*pi))), ...
              'opp', num2cell(opp));

info = struct();
info.definitionVersion = 'golden_spiral_nearest_dedup_v2';
info.Wdeg = Wdeg;
info.Hdeg = Hdeg;
info.deltaFx = 1/Wdeg;
info.deltaFy = 1/Hdeg;
info.initialProposalCount = double(targetCount);
info.proposalCountUsed = proposalCount;
info.requestedAxisCount = requestedAxes;
info.maxSF = maxSF;
info.minSFRequested = minSF;
info.minSFUsed = minSFUsed;
info.densityExponent = densityExponent;
info.goldenAngleRad = goldenAngle;
info.radialRule = radialRule;
info.snapRule = 'independent nearest periodic point, then canonical deduplication';
info.canonicalRule = 'kx>0 or (kx==0 and ky>0)';
info.uniqueAxesBeforeSelection = uniqueBeforeSelection;
info.physicalAxisCount = nAxes;
info.duplicateAssignmentsRemoved = proposalCount - uniqueBeforeSelection;
info.axesDownselected = uniqueBeforeSelection - nAxes;
info.medianSnapError = median(snapError);
info.maxSnapError = max(snapError);
info.canonicalFirstTargetIndex = firstOccurrence;
end

function [canonicalK, firstOccurrence, snapError, minSFUsed, radialRule] = ...
    localSnapAndDeduplicate(Wdeg, Hdeg, proposalCount, maxSF, ...
    densityExponent, minSF, goldenAngle)

i = (1:proposalCount).';
if densityExponent == -2
    if minSF == 0
        minSFUsed = min(1/Wdeg, 1/Hdeg);
    else
        minSFUsed = minSF;
    end
    t = (i-1) / max(proposalCount-1, 1);
    r = minSFUsed * (maxSF/minSFUsed).^t;
    radialRule = 'log radius: equal proposal count per octave';
else
    minSFUsed = 0;
    t = i / proposalCount;
    r = maxSF * t.^(1/(densityExponent+2));
    radialRule = 'power-law areal proposal density rho(r) proportional to r^p';
end
theta = goldenAngle * i;
targetFx = r .* cos(theta);
targetFy = r .* sin(theta);

snappedK = zeros(proposalCount,2);
snapError = zeros(proposalCount,1);
offset = -2:2;
for j = 1:proposalCount
    kx0 = round(targetFx(j)*Wdeg);
    ky0 = round(targetFy(j)*Hdeg);
    [candidateKx,candidateKy] = ndgrid(kx0+offset,ky0+offset);
    candidateFx = candidateKx/Wdeg;
    candidateFy = candidateKy/Hdeg;
    valid = ~(candidateKx==0 & candidateKy==0) & ...
        hypot(candidateFx,candidateFy) <= maxSF + 32*eps(maxSF);
    d2 = (candidateFx-targetFx(j)).^2 + (candidateFy-targetFy(j)).^2;
    d2(~valid) = Inf;
    [bestD2,best] = min(d2(:));
    if ~isfinite(bestD2)
        error('No valid periodic lattice point found near spiral target %d.',j);
    end
    snappedK(j,:) = [candidateKx(best),candidateKy(best)];
    snapError(j) = sqrt(bestD2);
end

flipSign = snappedK(:,1) < 0 | (snappedK(:,1)==0 & snappedK(:,2)<0);
snappedK(flipSign,:) = -snappedK(flipSign,:);
[canonicalK,firstOccurrence] = unique(snappedK,'rows','stable');
end
