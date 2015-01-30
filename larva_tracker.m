%% initialize settings

video_name = 'IMGP0521.AVI';

% The size of the area you want to search (in pixels).
search_size = 20;

% The average pixel intensity in the search area must exceed this value to
% log a position and NOT skip the frame. Prevents random noise and other
% weird stuff from "becoming the fly." Essentially requires any given blob
% it detects to be above a certain size and intensity.
per_pixel_threshold = 1.5;

% Default settings for dimensions of assay, units in cm. Only change
% if you're using a different via l than normal.
inner_diameter = 10;

%% open video

disp(strcat('Opening', {' '}, video_name, ', please wait.'));
vr = VideoReader(video_name);
resolution = [vr.Width vr.Height];
nfrm_movie = floor(vr.Duration * vr.FrameRate);

% define region of interest (ROI) 
disp('Click and drag to define a rectangular region of interest, double-click to proceed.');
figure('name', 'ROI select'), imshow(read(vr, 1));
ROI_select = imrect;
ROI = wait(ROI_select); %ROI takes form of [xmin ymin width height]
close gcf;

%% create a background

disp('Calculating image background.');

% Pick a random set of 100 frames to create the background.
bg_number = 100;
randv = rand(bg_number,1);
bg_idx = sort(round(randv * nfrm_movie));

% Read each frame of the background and average them to create a background
% image.
bg_array = zeros(resolution(2), resolution(1), bg_number, 'uint8');
bg_step = 0;
while bg_step < bg_number
    bg_step = bg_step + 1;
    bg_frame = rgb2gray(read(vr, bg_idx(bg_step)));
    bg_array(:,:,bg_step) = bg_frame;
end
background =  uint8(mean(bg_array, 3));
background = imcrop(background, ROI);

%% analyze each frame of the video and subtract background

disp('Calculating larvae positions (this part takes awhile...).');

% re-define search parameters to make sense regardless of size
threshold = (search_size)^2 * per_pixel_threshold;
search_size = round(search_size / 2);

%initialize arrays used to log position
num_larvae = 5;
position = zeros(nfrm_movie, num_larvae + 1);

%process frames of video for fly
binaryVideo = zeros(ROI(3), ROI(4) ,nfrm_movie);
waitDialog = waitbar(0, 'Creating binary maps from images...');
for nofr = 1:nfrm_movie
    waitbar(nofr/nfrm_movie, waitDialog, ...
        strcat({'Analyzing frame'},{' '}, num2str(nofr), {' '}, {'of'}, {' '}, num2str(nfrm_movie)));
    
    % Extract image from video.
    frameInt = rgb2gray(read(vr, nofr));
    frame = imcrop(frameInt, ROI);
    
    % Subtract image background.
    frame = frame - background;
    
    % Threshold image.
    thresh = graythresh(frame);
    frame = medfilt2(im2bw(frame, thresh));
    
    % Dump image to binaryVideo for later separation
    binaryVideo(:,:,nofr);
end
close(waitDialog);

%% process and output data

disp('Creating output.');

%Convert position coordinates to real, meaningful positions (coordinates in
%cm and time in seconds. Scale is in cm/pixels.
xscale = inner_diameter / ROI_top(3);
yscale_top = ROI_top(4); % need to change ROI for second fly
yscale_bottom = bottom_half_height / ROI_bottom(4);

%convert to coordinates in cm and frame number to seconds, add coordinate
%offset for bottom fly
corrected_array = [position(:,1)/vr.FrameRate, ...
    position(:,2) * xscale, ...
    (position(:,3) * yscale_bottom);

% create a new figure and plot fly path
figure('Name','Fly pathing map');
plot(corrected_array(:,2), corrected_array(:,3), ...
    corrected_array(:,4), corrected_array(:,5));
axis([0 inner_diameter 0 (bottom_half_height + top_half_height)], 'equal', 'manual');
xlabel('X-coordinate (cm)', 'fontsize', 11);
ylabel('Y-coordinate (cm)', 'fontsize', 11);
legend('Fly 1 (bottom)', 'Fly 2 (top)', 'location', 'southoutside');
% inverts the y coordinates to match the video
set(gca, 'Ydir', 'reverse');

% write output
[output_name,path] = uiputfile('.csv');
output_array = corrected_array;
if (output_name ~= 0)  % in case someone closes the file saving dialog
    csvwrite(strcat(path,output_name), output_array);
else
    disp('File saving cancelled.')
end
