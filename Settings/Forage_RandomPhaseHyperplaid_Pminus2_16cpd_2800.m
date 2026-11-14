function [S,P] = Forage_RandomPhaseHyperplaid_Pminus2_16cpd_2800()
% Experiment 2: 4540 proposals realize 2800 axes on the treadmill display.
[S,P] = Forage_Hartleyplaid_Dense();
P.noisetype = 15;
P.hp_spiralBank = 1;
S.hp_spiralBank = 'Use golden-angle nearest/deduplicated bank (0 or 1):';
P.hp_spiralTargetCount = 4540;
S.hp_spiralTargetCount = 'Continuous golden-angle proposal count:';
P.hp_spiralAxisCount = 0;
S.hp_spiralAxisCount = 'Exact-axis targeting (0 keeps every deduplicated axis):';
P.hp_maxSF = 16;
S.hp_maxSF = 'Radial spatial-frequency limit (cycles/degree):';
P.hp_spiralDensityExponent = -2;
S.hp_spiralDensityExponent = 'Areal proposal-density exponent p:';
P.hp_spiralMinSF = 0;
S.hp_spiralMinSF = 'Minimum cpd (0 starts at the lattice limit):';
P.hp_K = 6;
S.protocolTitle = 'RP p-2 16cpd 2800 axes';
end
