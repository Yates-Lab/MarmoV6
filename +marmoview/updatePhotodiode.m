function [flashtime, flashOutTimings, flashOn] = updatePhotodiode(winPtr,S,outputs,frameCount,currentTime,flashtime,flashOutTimings)
%UPDATEPHOTODIODE Draw the photodiode patch and send configured TTL.

if nargin < 3 || isempty(outputs)
    outputs = {};
end
if nargin < 5 || isempty(currentTime)
    currentTime = GetSecs;
end
if nargin < 6 || isempty(flashtime)
    flashtime = [];
end
if nargin < 7
    flashOutTimings = [];
end

flashOn = false;
if ~isfield(S,'photodiode') || ~isfield(S.photodiode,'rect')
    return
end

tf = S.photodiode.TF;
if isempty(tf) || tf <= 0
    tf = 1;
end

periodFrames = max(1, round(S.frameRate/tf));
flashFrames = 1;
if isfield(S.photodiode,'flashFrames') && ~isempty(S.photodiode.flashFrames)
    flashFrames = S.photodiode.flashFrames;
end
flashFrames = min(max(1, round(flashFrames)), periodFrames);

flashStartFrame = 1;
if isfield(S.photodiode,'flashStartFrame') && ~isempty(S.photodiode.flashStartFrame)
    flashStartFrame = S.photodiode.flashStartFrame;
end
flashStartFrame = min(max(0, round(flashStartFrame)), periodFrames - 1);
framePhase = rem(frameCount, periodFrames);

if frameCount >= flashStartFrame
    flashEndFrame = flashStartFrame + flashFrames;
    if flashEndFrame <= periodFrames
        flashOn = framePhase >= flashStartFrame && framePhase < flashEndFrame;
    else
        flashEndPhase = rem(flashEndFrame, periodFrames);
        flashOn = framePhase >= flashStartFrame || framePhase < flashEndPhase;
    end
end

if flashOn
    Screen('FillRect',winPtr,S.photodiode.flash,S.photodiode.rect);
    flashtime = [flashtime; currentTime];
    timings = marmoview.setPhotodiodeTTL(S,outputs,1);
    if ~isempty(timings) || ~isempty(flashOutTimings)
        flashOutTimings = [flashOutTimings; timings];
    end
else
    Screen('FillRect',winPtr,S.photodiode.init,S.photodiode.rect);
    marmoview.setPhotodiodeTTL(S,outputs,0);
end

end
