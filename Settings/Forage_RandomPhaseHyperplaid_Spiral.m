function [S,P] = Forage_RandomPhaseHyperplaid_Spiral()
% Random-phase Fourier components from a snapped golden-angle spiral bank.
% Other task and timing parameters inherit the dense 4-cpd preset.
[S,P] = Forage_Hartleyplaid_Dense();
P.noisetype = 15;
P.hp_spiralBank = 1;
S.hp_spiralBank = 'Use golden-angle snapped Fourier bank (0 or 1):';
P.hp_spiralTargetCount = 2000;
S.hp_spiralTargetCount = 'Continuous spiral targets before canonicalization:';
P.hp_spiralAxisCount = 0;
S.hp_spiralAxisCount = 'Requested unique axes (0 keeps all deduplicated axes):';
P.hp_spiralMaxSF = 4;
S.hp_spiralMaxSF = 'Radial spatial-frequency limit (cycles/degree):';
P.hp_spiralDensityExponent = -1;
S.hp_spiralDensityExponent = 'Areal density exponent p (minimum -2):';
P.hp_spiralMinSF = 0;
S.hp_spiralMinSF = 'Minimum cpd for p=-2 (0 uses lattice minimum):';
S.protocolTitle = 'Forage random-phase spiral';
end
