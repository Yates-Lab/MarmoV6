% Sourced from https://natural-scenes.cps.utexas.edu/db.shtml
%Natural scenes set 9
%Geisler WS & Perry JS (2011). Statistics for optimal point prediction in natural images. Journal of Vision. October 19, 2011 vol. 11 no. 12 article 14. pdf


% Note I did not correct for camera RGB to sRGB so these aren't good
% color reconstructions of the screen

imfiles=dir('C:\Users\Declan\Downloads\ImageBank\cps20101012.ppm')

for ii =3:length(imfiles)
im=double(importdata(['C:\Users\Declan\Downloads\ImageBank\cps20101012.ppm\' imfiles(ii).name]));
b=uint8(255*(im)./(prctile(im(:),97.5)));
image(b); axis equal tight
imwrite(b,['C:\Users\Declan\Downloads\ImageBank\cps20101012.ppm\out\' imfiles(ii).name(1:end-4) '.jpeg'],'JPEG');
end