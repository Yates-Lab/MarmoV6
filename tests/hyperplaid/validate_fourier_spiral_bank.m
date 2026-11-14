function info = validate_fourier_spiral_bank(Wdeg, Hdeg)
% Validate the snapped golden-angle bank without opening a PTB window.
if nargin < 2
    % July treadmill geometry: 2560x1440 at the rig's calibrated ppd.
    pixPerDeg = 50.91435299254751;
    Wdeg = 2560 / pixPerDeg;
    Hdeg = 1440 / pixPerDeg;
end

[bank, info] = stimuli.buildGoldenSpiralFourierBank(Wdeg, Hdeg, 2000, 4);
nAxes = numel(bank) / 2;
kx = [bank.kx];
ky = [bank.ky];

assert(nAxes == info.physicalAxisCount);
assert(all([bank(1:nAxes).opp] == (nAxes+1:2*nAxes)));
assert(all(kx(nAxes+1:end) == -kx(1:nAxes)));
assert(all(ky(nAxes+1:end) == -ky(1:nAxes)));
assert(all(kx(1:nAxes) > 0 | ...
    (kx(1:nAxes) == 0 & ky(1:nAxes) > 0)));
assert(size(unique([kx(1:nAxes).' ky(1:nAxes).'], 'rows'), 1) == nAxes);

% p=-2 is the logarithmic-radius special case and must remain selectable.
[logBank, logInfo] = stimuli.buildGoldenSpiralFourierBank( ...
    Wdeg, Hdeg, 2000, 4, -2, 0);
assert(~isempty(logBank));
assert(logInfo.densityExponent == -2);
assert(logInfo.minSFUsed > 0);
assert(all(isfinite([logBank.fx])) && all(isfinite([logBank.fy])));

fprintf(['Validated %d canonical physical axes; %d duplicate target ' ...
    'assignments removed; median snap error %.5f cpd; maximum %.5f cpd.\n'], ...
    nAxes, info.duplicateAssignmentsRemoved, ...
    info.medianSnapError, info.maxSnapError);

% Exact requested-axis mode must return the requested physical-axis count.
[exactBank, exactInfo] = stimuli.buildGoldenSpiralFourierBank( ...
    Wdeg, Hdeg, 500, 4, -1, 0, 500);
assert(numel(exactBank)/2 == 500);
assert(exactInfo.physicalAxisCount == 500);
end
