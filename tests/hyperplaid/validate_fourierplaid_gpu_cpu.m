function results = validate_fourierplaid_gpu_cpu(stim)
%VALIDATEFOURIERPLAID_GPU_CPU Compare shader output with the CPU formula.
%   Run on the treadmill rig with a dedicated fourierplaid_procedural
%   object. Tests an oblique component at phases 0, pi/2, pi, and 3*pi/2,
%   which exposes y-axis or phase-sign convention errors.

if ~isa(stim,'stimuli.fourierplaid_procedural')
    error('Input must be a stimuli.fourierplaid_procedural object.');
end

phases = [0 pi/2 pi 3*pi/2];
kx = 7; ky = 5; amplitude = 0.25;
Wdeg = RectWidth(stim.screenRect)/stim.pixPerDeg;
Hdeg = RectHeight(stim.screenRect)/stim.pixPerDeg;
results = repmat(struct,1,numel(phases));

for i = 1:numel(phases)
    stim.K = 1;
    stim.current = struct('idx',NaN,'kx',kx,'ky',ky, ...
        'fx',kx/Wdeg,'fy',ky/Hdeg,'sf',hypot(kx/Wdeg,ky/Hdeg), ...
        'ori',rad2deg(mod(atan2(ky/Hdeg,kx/Wdeg),2*pi)), ...
        'phase',phases(i),'amp',amplitude);
    stim.beforeFrame();
    Screen('Flip',stim.winPtr);
    gpu = mean(Screen('GetImage',stim.winPtr,stim.screenRect,[],1),3);
    cpu = double(stim.getImage(stim.screenRect,1))/255;
    delta = double(gpu)-cpu;
    results(i).phaseRad = phases(i);
    results(i).rmse = sqrt(mean(delta(:).^2));
    results(i).maximumAbsoluteError = max(abs(delta(:)));
    fprintf('phase %.4f: RMSE %.6f, max abs %.6f\n', ...
        phases(i),results(i).rmse,results(i).maximumAbsoluteError);
end
end
