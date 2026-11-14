function [S,P] = Forage_RandomPhaseHyperplaid_Isotropic()
% Random-phase Fourier components on the isotropic Hartley lattice.
[S,P] = Forage_Hartleyplaid_Isotropic();
P.noisetype = 15;
S.protocolTitle = 'Forage random-phase isotropic';
end
