% a short script to open an image and calculate the position of a fruit fly
% against a light background

%% open video

%input video name here
video_name = 'half_res.AVI';

vr = VideoReader(video_name);
resolution = [vr.Width vr.Height]; 
nfrm_movie = floor(vr.Duration * vr.FrameRate);

%% define region of interest (ROI)

disp('Click and drag to define region of interest, double-click to proceed.');
figure, imshow(read(vr, 1));
ROI_select = imrect;
ROI = wait(ROI_select);
disp('ROI selected, proceeding with video analysis.');
%ROI takes form of [xmin ymin width height]

%% create a background

disp('Calculating image background.');

%pick a random set of 100 frames to create the background
bg_number = 100;
randv = rand(bg_number,1);
bg_idx = sort(round(randv * nfrm_movie));

%read each frame of the background and average them to create a background
%image
bg_array = zeros(resolution(2), resolution(1), bg_number, 'uint8');
bg_step = 0;
while bg_step < bg_number
    bg_step = bg_step + 1;
    bg_frame = rgb2gray(read(vr, bg_idx(bg_step)));
    bg_array(:,:,bg_step) = bg_frame;
end 
background =  uint8(mean(bg_array, 3));

%% analyze each frame of the video and subtract background

disp('Calculating fly positions.');

%initialize array used to log position
position_array = zeros(nfrm_movie,3);
for nofr = 1:nfrm_movie
    % extract image from video
    frame_gray = rgb2gray(read(vr, nofr));
    
    %"subtract" background image using GIMP's image division layer mode
    %formula (TWICE!)
    frame_gray = uint8((256 * double(frame_gray))./(double(background) + 1));
    frame_gray = uint8((256 * double(frame_gray))./(double(background) + 1));
    
    %extract ROI
    frame_crop = imcrop(frame_gray, ROI);
    
    %find darkest pixel on image and its coordinates... should be the fly!
    minValue = min(frame_crop(:));
    [ypos, xpos] = find(frame_crop == minValue);
    fr_position = [mean(xpos), mean(ypos), nofr];
    position_array(nofr,:) = fr_position;
end 
%correct position coordinates for ROI operation and convert frame number to
%time in seconds
position_array = [position_array(:,1) + ROI(1), ...
    position_array(:,2) + ROI(2), ...
    position_array(:,3)/vr.FrameRate];

%% plot positions

disp('Creating output.');
plot(position_array(:,1), position_array(:,2))
axis([0 resolution(1) 0 resolution(2)])
% inverts the y coordinates to match the video
set(gca, 'Ydir', 'reverse')