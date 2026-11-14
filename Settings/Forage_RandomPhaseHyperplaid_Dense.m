function [S,P] = Forage_RandomPhaseHyperplaid_Dense()
% Random-phase Fourier components on the dense Hartley lattice.
[S,P] = Forage_Hartleyplaid_Dense();
P.noisetype = 15;
S.protocolTitle = 'Forage random-phase dense';
end
