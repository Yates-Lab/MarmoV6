function [S,P] = Forage_RandomPhaseHyperplaid()
% Random-phase Fourier components on the standard Hartley lattice.
[S,P] = Forage_Hartleyplaid();
P.noisetype = 15;
S.protocolTitle = 'Forage random-phase hyperplaid';
end
