function [Exp] = import_eye_position(Exp, varargin)
% Import Eye Position for MarmoV5 session
% Arguments:
%   Exp         - Marmoview data structure
%   DataFolder  - Path where the raw eye traces live
% Optional arguments (as key/value pairs):
%   TAGSTART    - value to identify as a trial start (default: 63)
%   TAGEND      - value to identify as trial end (default: 64)
%   fid         - file id to dump to (default: 1 => dumps to command window)
% Outputs:
%   Exp         - updated data struct, now with vpx and vpx2ephys added
%   fig         - sync figure, returns empty if sync didn't work properly

ip = inputParser();
ip.addParameter('TAGSTART', 63)
ip.addParameter('TAGEND', 62)
ip.addParameter('fid', 1)
ip.addParameter('zero_mean', false)
ip.addParameter('normalize', false)
ip.parse(varargin{:});

TAGSTART = ip.Results.TAGSTART;
TAGEND = ip.Results.TAGEND;

fig = [];
fid = ip.Results.fid;
%% Loading up the VPX file as a long data stream
% Can be done later, might just use matlab eye data for now
%*****************************************************************
DDPI = 0;
EDF = 0;
fprintf(fid, 'USING ONLINE EYE POSITION\n');

numTrials = numel(Exp.D);
Exp.vpx = struct();
Exp.vpx.raw = []; % time, x, y, pupil
for iTrial = 1:numTrials
    ix = ~isnan(Exp.D{iTrial}.eyeData(:,1));
    tmp = Exp.D{iTrial}.eyeData(:,1:4);
    Exp.vpx.raw = [Exp.vpx.raw; tmp(ix,:)];
end

badsamples = (diff(Exp.vpx.raw(:,1))==0);

%% Zero samples are bad samples with OpenIris
badsamples = ([badsamples; 0])|(Exp.vpx.raw(:,2)==0)|(Exp.vpx.raw(:,3)==0);
%%

Exp.vpx.raw(badsamples,:) = [];
badsamples = Exp.vpx.raw(:,1)==0;
Exp.vpx.raw(badsamples,:) = [];
Exp.vpx.smo = Exp.vpx.raw;
Exp.vpx2ephys = @(x) (x);

% eliminate double samples (this shouldn't do anything)
[~,ia] =  unique(Exp.vpx.raw(:,1));
Exp.vpx.raw = Exp.vpx.raw(ia,:);

Exp.vpx.raw0= Exp.vpx.raw;



% upsample eye traces to 1kHz
new_timestamps = Exp.vpx.raw(1,1):1e-3:Exp.vpx.raw(end,1);
new_EyeX = interp1(Exp.vpx.raw(:,1), Exp.vpx.raw(:,2), new_timestamps);
new_EyeY = interp1(Exp.vpx.raw(:,1), Exp.vpx.raw(:,3), new_timestamps);
new_Pupil = interp1(Exp.vpx.raw0(:,1), Exp.vpx.raw0(:,4), new_timestamps);
bad = interp1(Exp.vpx.raw(:,1), double(Exp.vpx.raw(:,2)>31e3), new_timestamps);
Exp.vpx.raw = [new_timestamps(:) new_EyeX(:) new_EyeY(:) new_Pupil(:)];

Exp.vpx.raw(bad>0,2:end) = nan; % nan out bad sample times
Exp.vpx.raw(:,3) = -Exp.vpx.raw(:,3) + 1;

%% convert eye position to degrees
%             Exp = get_smo_eyetrace(Exp);

Exp = get_smo_eyetrace(Exp);


function Exp = get_smo_eyetrace(Exp)
Fs = 1./nanmedian(diff(Exp.vpx.raw(:,1)));
% x and y position
vxx = Exp.vpx.raw(:,2);
vyy = 1 - Exp.vpx.raw(:,3);
vtt = Exp.vpx.raw(:,1);

%--- OLD WAY: use most common calibraiton
% use the most common value across trials (we should've only calibrated
% once in these sessions)
% cx = mode(cxs);
% cy = mode(cys);
% dx = mode(dxs);
% dy = mode(dys);
% 
% % convert to d.v.a.
% vxxd = (vxx - cx)/(dx * Exp.S.pixPerDeg);
% vyy = 1 - vyy;
% vyyd = (vyy - cy)/(dy * Exp.S.pixPerDeg);

% NEW WAY, wait why would we do a new calibration for each trial -> I think
% I put this in for a few times where we adjusted the head during a session
%  but it % shouldn't be necessary
nTrials = numel(Exp.D);
validTrials = 1:nTrials;

% gain and offsets from online calibration
cxs = cellfun(@(x) x.c(1), Exp.D(validTrials));
cys = cellfun(@(x) x.c(2), Exp.D(validTrials));
dxs = cellfun(@(x) x.dx, Exp.D(validTrials));
dys = cellfun(@(x) x.dy, Exp.D(validTrials));

vxxd = vxx;
vyyd = vyy;

for iTrial = 1:nTrials
    tstartPtb = (Exp.D{iTrial}.STARTCLOCKTIME);
    tstartVpx = find(Exp.vpx2ephys(vtt) > tstartPtb, 1);
    if iTrial < nTrials
        tNextPtb = (Exp.D{iTrial+1}.STARTCLOCKTIME);
        tEndVpx = find(Exp.vpx2ephys(vtt) > tNextPtb, 1);
    else
        tEndVpx = numel(vtt);
    end
    
    iix = tstartVpx:tEndVpx;
        
    cx = cxs(1);
    cy = cys(1);
    dx = dxs(1);
    dy = dys(1);
    
    % convert to d.v.a.
    vxxd(iix) = (vxx(iix) - cx)/(dx * Exp.S.pixPerDeg);
    vyyd(iix) = (vyy(iix) - cy)/(dy * Exp.S.pixPerDeg);

end

vpp = Exp.vpx.raw(:,4);

vxx = medfilt1(vxxd, 5);
vyy = medfilt1(vyyd, 5);

vxx = imgaussfilt(vxx, 7);
vyy = imgaussfilt(vyy, 7);

vx = [0; diff(vxx)];
vy = [0; diff(vyy)];

vx = sgolayfilt(vx, 1, 3);
vy = sgolayfilt(vy, 1, 3);

% convert to d.v.a / sec
vx = vx * Fs;
vy = vy * Fs;

spd = hypot(vx, vy);
Exp.vpx.smo = [vtt vxxd vyyd vpp vx vy spd];

