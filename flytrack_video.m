% a short script to open an image and calculate the position of a fruit fly
% against a light background

%% open video

vr = VideoReader('huge_movie.AVI');
resolution = [vr.Width vr.Height]; 
Nfrm_movie = floor(vr.Duration * vr.FrameRate);

%% create a background

%pick a random set of 100 frames to create the background
randv = rand(100,1);
bg_idx = sort(round(randv * Nfrm_movie));

%read each frame of the background and average them
bg_array = zeros(resolution(2), resolution(1), 100, 'uint8');
bg_step = 0;
while bg_step <= 0
    bg_step = bg_step + 1;
    bg_frame = rgb2gray(read(vr, bg_idx(bg_step)));
    bg_array = bg_frame;
end 

%background = mean(read(vr, bg_idx));

%% analyze each frame of the video and subtrack background

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