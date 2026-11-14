function test_canonicalizeFourierComponent()
% Basic identity and convention checks for canonicalizeFourierComponent.
kx = [-3 0 2 -4 0];
ky = [ 2 -5 -1 -7 0];
phase = [0 pi/2 pi 3*pi/2 7*pi];
[kxc, kyc, phasec, flipped] = canonicalizeFourierComponent(kx, ky, phase);

assert(isequal(flipped, [true true false true false]));
assert(all((kxc > 0) | (kxc == 0 & kyc >= 0)));
assert(all(phasec >= 0 & phasec < 2*pi));

x = linspace(-0.5, 0.5, 31).';
y = linspace(0.5, -0.5, 31).';
before = cos(2*pi*(x*kx + y*ky) + phase);
after = cos(2*pi*(x*kxc + y*kyc) + phasec);
assert(max(abs(before(:)-after(:))) < 1e-12);
end
