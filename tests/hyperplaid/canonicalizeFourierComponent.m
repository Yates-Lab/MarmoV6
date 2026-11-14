function [kxCanonical, kyCanonical, phaseCanonical, flipped] = ...
    canonicalizeFourierComponent(kx, ky, phaseRad)
%CANONICALIZEFOURIERCOMPONENT Give equivalent components one representation.
%   Negative axes are reflected to the half-plane kx>0 or kx==0,ky>=0.
%   When k is reflected, phase becomes -phase modulo 2*pi so that
%   cos(-k.x + phase) == cos(k.x - phase).

if ~isequal(size(kx), size(ky), size(phaseRad))
    error('kx, ky, and phaseRad must have identical sizes.');
end

kxCanonical = kx;
kyCanonical = ky;
phaseCanonical = mod(phaseRad, 2*pi);
flipped = (kx < 0) | (kx == 0 & ky < 0);
kxCanonical(flipped) = -kxCanonical(flipped);
kyCanonical(flipped) = -kyCanonical(flipped);
phaseCanonical(flipped) = mod(-phaseCanonical(flipped), 2*pi);
end
