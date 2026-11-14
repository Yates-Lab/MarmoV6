% Load all images in a subdirectory into a 3D array
cd('C:\Users\Declan\Documents\MATLAB\MarmoV6')
%%
mp4dir='C:\Users\Declan\Documents\MATLAB\MarmoV6\SquirrelTest\TestDaVinciStab3.mp4';
% Specify dimensions of each image
% W = 3840;
% H = 2160; %?

% Get a list of all image files in the directory
%mp4File = dir(fullfile(mp4dir, '*.mp4'));
mp4File = dir(mp4dir);
%% Example frames
vidObj = VideoReader(fullfile(mp4File.folder, mp4File.name));
vidframes = read(vidObj,[1 Inf]);
nFrames=size(vidframes,4);
 %% Check pixel value range
% for ii=1:2:nFrames
% % Read the image
% img = mean(vidframes(:,:,:,ii),3)./256;
% subplot(211);imagesc(img);colormap(gray)
% axis equal tight
% subplot(212);histogram(img(:),256)
% pause(0.01)
% end
% 
% %%
% greysc=squeeze(mean(vidframes(:,:,:,:),3));
% histogram(greysc(:),256)
% 
% %%
% scld=(greysc-25)/150;
% histogram(scld(:),256);
% %%
% scld(scld<0)=0;
% scld(scld>1)=1;

%%
vidObj = VideoReader(fullfile(mp4File.folder, mp4File.name));
nFrames=vidObj.NumFrames;
for jj=1:nFrames
    vidframe = read(vidObj,[jj]);
    img = mean(vidframe,3)./256;
    scld=(img-.1)/2.00;
    scld(scld<0)=0;
    scld(scld>1)=1;
    imagesc(scld); colormap(gray); axis equal tight
    pause(0.01)
end


%%
vidObj = VideoReader(fullfile(mp4File.folder, mp4File.name));
nFrames=vidObj.NumFrames;
%%
v = VideoWriter(fullfile(['SqCam_test7.avi']),'Grayscale AVI');
v.FrameRate=30; %Gopro native framerate
open(v)
for ii=1:nFrames
    vidframe = read(vidObj,[ii]);
    img = mean(vidframe,3)./256;
    scld=(img-.05)/2.00;
    scld(scld<0)=0;
    scld(scld>1)=1;

    writeVideo(v,img); %just taking mean RGB channels as greyscale
end
close(v)
