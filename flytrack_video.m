% a short script to open an image and calculate the position of a fruit fly
% against a light background

%% open video

vr = VideoReader('fly_movie.AVI');
resolution = [vr.Width vr.Height]; 
Nfrm_movie = floor(vr.Duration * vr.FrameRate);

%% analyze each frame of the video

%initialize array used to log position
position_array = zeros(Nfrm_movie,3);

for nofr = 1:Nfrm_movie
    % extract image from video
    frame = read(vr, nofr);
    frame_gray = rgb2gray(frame);
    
    %find darkest point on image and its coordinates
    minValue = min(frame_gray(:));
    [ypos, xpos] = find(frame_gray == minValue);

    fr_position = [mean(xpos), mean(ypos), nofr];
    position_array(nofr,:) = fr_position;
end 

%% plot positions

% invert the y coordinates to match the video
plot(position_array(:,1), position_array(:,2))
axis([0 resolution(1) 0 resolution(2)])
set(gca, 'Ydir', 'reverse')