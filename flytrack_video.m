%% initialize settings

% A short script to open an image and calculate the position of a fruit fly
% against a light background. Output graph is a sanity check for the
% path of the fly. 

% Known issues: 
% -Fly path is a little bit "jagged." This is caused by limited camera
% resolution and the image rotation correction. To reduce 'jaggedness,'
% take straigter videos (at least until I implement per-image antialiasing).
% -High numbers of skipped frames if fly just sits around for most of the
% video.

% Written by Jeff Stafford. Some code and ideas from Dan Valente's FTrack
% suite were used, as well as the 'Division' layer mode formula from GIMP.

%input dimensions of assay vial, units in cm
top_half_height = 3;
bottom_half_height = 8;
inner_diameter = 1.5;

%input video name here. MUST BE IN WORKING DIRECTORY OF THIS SCRIPT.
video_name = 'IMGP0172.AVI';

search_size = 20;
threshold = 25;

%do you want .csv output?
output = false;
%if so, what do you want it to be named?
output_name = '174.csv';
% key to output csv (fly 1 is on the bottom half of the vial):
% column 1 = Time (in seconds)
% column 2 = Fly 1 x position (in cm from left edge of furthest left ROI)
% column 3 = Fly 1 y position (in cm from absolute top of vial)
% column 4 = Fly 2 x position
% column 5 = Fly 2 y position

%% open video

disp('Opening video, please wait.')
vr = VideoReader(video_name);
resolution = [vr.Width vr.Height]; 
nfrm_movie = floor(vr.Duration * vr.FrameRate);

%% define region of interest (ROI) and eliminate LR camera tilt

%Draw a line to calculate camera tilt.
disp('Click and drag along the edge of the vial to correct for camera tilt, double-click to proceed.');
figure('name', 'Rotation correction'), imshow(read(vr, 1));
line_select = imline;
line = wait(line_select);
%Determine angle of correction rotation.
rotation_angle = 360 - (57.3 * atan((line(1,1) - line(2,1)) / (line(1,2) - line(2,2)) ) );
%Determine number of pixels after rotation.
%resolution = size(imrotate(read(vr, 1), rotation_angle));
close gcf;

disp('Click and drag to define a rectangular region of interest, double-click to proceed.');
figure('name', 'ROI select'), imshow(imrotate(read(vr, 1), rotation_angle ));
ROI_select = imrect;
ROI = wait(ROI_select); %ROI takes form of [xmin ymin width height]
close gcf; 

%split into 2 ROIs, on% add NaNs to array if fly is not founde for each fly
total_height = top_half_height + bottom_half_height;
ROI_top = ROI;
ROI_top(4) = (top_half_height / total_height) * ROI_top(4);

ROI_bottom = ROI;
ROI_bottom(4) = (bottom_half_height / total_height) * ROI_bottom(4);
ROI_bottom(2) = ROI_bottom(2) + ROI_top(4);

disp('ROI selected, proceeding with video analysis.');


%% create a background

disp('Calculating image background.');

%pick a random set of 100 frames to create the background
bg_number = 100;
randv = rand(bg_number,1);
bg_idx = sort(round(randv * nfrm_movie));
%bg_idx = (1:bg_number);

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
background = imrotate(background, rotation_angle);

%% analyze each frame of the video and subtract background

disp('Calculating fly positions (this part takes awhile...).');

%initialize arrays used to log position
bottom_array = zeros(nfrm_movie, 3);
top_array = zeros(nfrm_movie, 3);

%process frames of video for fly
for nofr = 1:nfrm_movie
    % extract image from video
    frame_int = rgb2gray(imrotate(read(vr, nofr), rotation_angle));
         
    %"subtract" background image using GIMP's image division layer mode
    %formula (TWICE!)
    frame_subtracted = uint8((256 * double(frame_int))./(double(background) + 1));
    frame_subtracted = uint8((256 * double(frame_subtracted))./(double(background) + 1));
    
    %Bottom ROI processing
    frame_crop = imcrop(frame_subtracted, ROI_bottom);

    %find darkest pixel on bottom ROI and its coordinates... should be the fly!
    minValue = min(frame_crop(:));
    [ypos, xpos] = find(frame_crop == minValue);
    xpos = mean(xpos);
    ypos = mean(ypos);
        
    % define 'excl' region in which the background is not updated
    excl_leftEdge = int16(round(xpos) - search_size);
    excl_rightEdge = int16(round(xpos) + search_size);
    excl_topEdge = int16(round(ypos) - search_size);
    excl_bottomEdge = int16(round(ypos) + search_size);
    
%     excl_leftEdge = int16(round((xpos + ROI_bottom(1)) - search_size));
%     excl_rightEdge = int16(round((xpos + ROI_bottom(1)) + search_size));
%     excl_topEdge = int16(round((ypos + ROI_bottom(2)) - search_size));
%     excl_bottomEdge = int16(round((ypos + ROI_bottom(2)) + search_size));
    % make sure excl does not fall outside ROI bounds
    if excl_leftEdge < 1
        excl_leftEdge = 1;
    end
    if excl_rightEdge > ROI_bottom(3);
        excl_rightEdge = ROI_bottom(3);
    end
    if excl_topEdge < 1
        excl_topEdge = 1;
    end
    if excl_bottomEdge > ROI_bottom(4);
        excl_bottomEdge = ROI_bottom(4);
    end
    
%     if excl_leftEdge < ROI_bottom(1)
%         excl_leftEdge = ROI_bottom(1);
%     end
%     if excl_rightEdge > ROI_bottom(1) + ROI_bottom(3);
%         excl_rightEdge = ROI_bottom(1) + ROI_bottom(3);
%     end
%     if excl_topEdge < ROI_bottom(2)
%         excl_topEdge = ROI_bottom(2);
%     end
%     if excl_bottomEdge > ROI_bottom(2) + ROI_bottom(4);
%         excl_bottomEdge = ROI_bottom(2) + ROI_bottom(4);
%     end
    
    bg_excl = [excl_leftEdge excl_rightEdge excl_topEdge excl_bottomEdge];
    search_area = frame_crop(bg_excl(3):bg_excl(4), bg_excl(1):bg_excl(2));
%     background = frame_int;
%     background(bg_excl(1):bg_excl(2), bg_excl(3):bg_excl(4)) = search_area;
    
    %flip to be white pixels on black
    fly_region = 255 - double(search_area);
    fly_region = 255 - fly_region;
    %FTRACK code
    x2 = [1:length(fly_region(1,:))]';
    y2 = [1:length(fly_region(:,1))]';
    total = sum(sum(fly_region));
    
    % add x and y positions to array if pixel intensity (the fly) is above a
    % certain threshold.
    if total >= threshold
        x = sum(fly_region*x2)/total+excl_leftEdge-1;
        y = sum(fly_region'*y2)/total+excl_topEdge-1;
        fr_position = [nofr, x, y];
    else % add NaNs to array if fly is not found
        fr_position = [nofr, NaN, NaN];
    end
    bottom_array(nofr,:) = fr_position;
    
%     %Top ROI processing
%     frame_crop = imcrop(frame_subtracted, ROI_top);
% 
%     minValue = min(frame_crop(:));
%     [ypos, xpos] = find(frame_crop == minValue);
%     fr_position = [nofr, mean(xpos), mean(ypos)];
%     top_array(nofr,:) = fr_position;
end

%correct position coordinates for ROI operation
position_array = [bottom_array(:,1), ...
    bottom_array(:,2) + ROI_bottom(1), ...
    bottom_array(:,3) + ROI_bottom(2), ...
    top_array(:,2) + ROI_top(1), ...
    top_array(:,3) + ROI_top(2)];

%% process and output data

disp('Creating output.');

%Convert position coordinates to real, meaningful positions (coordinates in
%cm and time in seconds. Scale is in cm/pixels. 
xscale = inner_diameter / ROI_top(3);

yscale_top = top_half_height / ROI_top(4); % need to change ROI for second fly
yscale_bottom = bottom_half_height / ROI_bottom(4);

%convert to coordinates in cm and frame number to seconds, add coordinate
%offset for bottom fly
corrected_array = [position_array(:,1)/vr.FrameRate, ...
    (position_array(:,2) - ROI_bottom(1)) * xscale, ...
    ((position_array(:,3) - ROI_bottom(2)) * yscale_bottom) + top_half_height, ...
    (position_array(:,4) - ROI_top(1)) * xscale, ...
    (position_array(:,5) - ROI_top(2)) * yscale_top];

plot(corrected_array(:,2), corrected_array(:,3), ...
    corrected_array(:,4), corrected_array(:,5))
axis([0 inner_diameter 0 (bottom_half_height + top_half_height)])
% inverts the y coordinates to match the video
set(gca, 'Ydir', 'reverse')

skipped1 = sum(isnan(corrected_array(:,2)));
disp(strcat(num2str(skipped1), ' frames were skipped out of ', num2str(length(corrected_array(:,2))), ' for fly 1.'));

if output == true
    output_array = corrected_array; 
    csvwrite(output_name, output_array);
end

% old code to look at raw position within the image
% plot(position_array(:,1), position_array(:,2))
% axis([0 resolution(1) 0 resolution(2)])
% % inverts the y coordinates to match the video
% set(gca, 'Ydir', 'reverse')