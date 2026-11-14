function bank = makeMarmosetFlowTrajectoryBank(options)
% MAKEMARMOSETFLOWTRAJECTORYBANK Reproducible pairs of independent flow-centre walks.
%
% Each pair holds two bounded, low-pass random walks for the two
% simultaneously presented contraction fields. The walks start on opposite
% sides of the fixation point (equidistant from the starting gaze), stay at
% least MinimumCentreSeparationDeg apart, and have near-zero velocity
% correlation so that gaze following can be attributed to one field.
%
% Required options: FrameRate, StimulusDuration, TrajectoryPairCount (or
% legacy TrajectoryCount), RandomSeed, SpeedDegPerSecond,
% MaximumEccentricityDeg, FilterTimeConstantSeconds.
% Optional: StartOffsetDeg (2.5), MinimumCentreSeparationDeg (4),
% MaximumVelocityCorrelation (0.2), MaximumAttempts (5000).
%
% XDeg and YDeg are [pair, walk, frame] arrays in degrees, +y up.

if isfield(options,'TrajectoryCount') && ~isfield(options,'TrajectoryPairCount')
    options.TrajectoryPairCount = options.TrajectoryCount;
end
required = {'FrameRate','StimulusDuration','TrajectoryPairCount','RandomSeed', ...
    'SpeedDegPerSecond','MaximumEccentricityDeg','FilterTimeConstantSeconds'};
for ii = 1:numel(required)
    if ~isfield(options,required{ii})
        error('makeMarmosetFlowTrajectoryBank:MissingOption', ...
            'Missing option %s.',required{ii});
    end
end
options = setDefault(options,'StartOffsetDeg',2.5);
options = setDefault(options,'MinimumCentreSeparationDeg',4);
options = setDefault(options,'MaximumVelocityCorrelation',0.2);
options = setDefault(options,'MaximumAttempts',5000);

nFrames = max(2,ceil(options.FrameRate*options.StimulusDuration));
nPairs = round(options.TrajectoryPairCount);
if nPairs < 1 || options.FrameRate <= 0 || options.StimulusDuration <= 0 || ...
        options.SpeedDegPerSecond < 0 || options.MaximumEccentricityDeg <= 0 || ...
        options.FilterTimeConstantSeconds <= 0 || options.StartOffsetDeg < 0 || ...
        options.StartOffsetDeg > options.MaximumEccentricityDeg
    error('makeMarmosetFlowTrajectoryBank:TrajectoryCount', ...
        'Trajectory and timing parameters must be positive and consistent.');
end
if 2*options.StartOffsetDeg < options.MinimumCentreSeparationDeg
    error('makeMarmosetFlowTrajectoryBank:StartSeparation', ...
        'Walks must start at least MinimumCentreSeparationDeg apart.');
end

stream = RandStream('mt19937ar','Seed',round(options.RandomSeed));
x = zeros(nPairs,2,nFrames);
y = zeros(nPairs,2,nFrames);
startAngle = zeros(nPairs,1);
minimumSeparation = zeros(nPairs,1);
velocityCorrelation = zeros(nPairs,1);
attempts = zeros(nPairs,1);
for pair = 1:nPairs
    accepted = false;
    while ~accepted
        attempts(pair) = attempts(pair)+1;
        if attempts(pair) > options.MaximumAttempts
            error('makeMarmosetFlowTrajectoryBank:Constraints', ...
                ['Could not satisfy separation/independence constraints ' ...
                'after %d attempts.'],options.MaximumAttempts);
        end
        angle = 2*pi*rand(stream);
        start = options.StartOffsetDeg*[cos(angle); sin(angle)];
        walkA = boundedWalk(stream,start,nFrames,options);
        walkB = boundedWalk(stream,-start,nFrames,options);
        separation = hypot(walkA(1,:)-walkB(1,:),walkA(2,:)-walkB(2,:));
        correlation = vectorCorrelation(diff(walkA,1,2),diff(walkB,1,2));
        accepted = min(separation) >= options.MinimumCentreSeparationDeg && ...
            abs(correlation) <= options.MaximumVelocityCorrelation;
    end
    x(pair,1,:) = walkA(1,:);
    y(pair,1,:) = walkA(2,:);
    x(pair,2,:) = walkB(1,:);
    y(pair,2,:) = walkB(2,:);
    startAngle(pair) = angle;
    minimumSeparation(pair) = min(separation);
    velocityCorrelation(pair) = correlation;
end

bank = struct();
bank.SchemaVersion = 'MarmosetFlowTrajectoryPairBank-2.0';
bank.RandomSeed = round(options.RandomSeed);
bank.FrameRate = options.FrameRate;
bank.StimulusDuration = options.StimulusDuration;
bank.SpeedDegPerSecond = options.SpeedDegPerSecond;
bank.MaximumEccentricityDeg = options.MaximumEccentricityDeg;
bank.FilterTimeConstantSeconds = options.FilterTimeConstantSeconds;
bank.StartOffsetDeg = options.StartOffsetDeg;
bank.MinimumCentreSeparationDeg = options.MinimumCentreSeparationDeg;
bank.MaximumVelocityCorrelation = options.MaximumVelocityCorrelation;
bank.StartAngleRad = startAngle;
bank.MinimumSeparationDeg = minimumSeparation;
bank.VelocityCorrelation = velocityCorrelation;
bank.GenerationAttempts = attempts;
bank.XDeg = x;
bank.YDeg = y;
end


function walk = boundedWalk(stream,start,nFrames,options)
alpha = exp(-1/(options.FrameRate*options.FilterTimeConstantSeconds));
noise = randn(stream,2,nFrames);
velocity = zeros(2,nFrames);
velocity(:,1) = noise(:,1);
for frame = 2:nFrames
    velocity(:,frame) = alpha*velocity(:,frame-1) + ...
        sqrt(1-alpha^2)*noise(:,frame);
end
speed = hypot(velocity(1,:),velocity(2,:));
velocity = velocity*(options.SpeedDegPerSecond/max(eps,median(speed)));

limit = options.MaximumEccentricityDeg;
walk = zeros(2,nFrames);
walk(:,1) = start;
for frame = 2:nFrames
    proposed = walk(:,frame-1) + velocity(:,frame)/options.FrameRate;
    radius = norm(proposed);
    if radius > limit
        outward = proposed/radius;
        velocity(:,frame:end) = reflect(velocity(:,frame:end),outward);
        proposed = walk(:,frame-1) + velocity(:,frame)/options.FrameRate;
        radius = norm(proposed);
        if radius > limit
            proposed = proposed*(limit/radius);
        end
    end
    walk(:,frame) = proposed;
end
end


function velocity = reflect(velocity,normal)
% Reflecting the remaining velocity keeps the low-pass heading continuous.
velocity = velocity - 2*normal*(normal'*velocity);
end


function r = vectorCorrelation(a,b)
a = a - mean(a,2);
b = b - mean(b,2);
denominator = sqrt(sum(a.^2,'all')*sum(b.^2,'all'));
if denominator == 0
    r = 0;
else
    r = sum(a.*b,'all')/denominator;
end
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
