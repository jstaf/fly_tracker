%% initialize settings

% A short script to open an image and calculate the position of a fruit fly
% against a light background. Output graph is a sanity check for the
% path of the fly. 

% Known issues: 
% -fly path is a little bit "jagged"
% -fly can "teleport" if the script doesn't find it in a frame
% -only one fly at the moment

% Jeff Stafford

%input dimensions of assay vial, units in cm
top_half_height = 3;
bottom_half_height = 8;
inner_diameter = 1.5;

%input video name here. MUST BE IN WORKING DIRECTORY OF THIS SCRIPT.
video_name = 'half_res.AVI';

%do you want output?
output = true;
%if so, what do you want it to be named?
output_name = 'tracker_out2.csv';
% key to output csv:
% column 1 = Time (in seconds)
% column 2 = Fly 1 x position (in cm from left edge of furthest left ROI)
% column 3 = Fly 1 y position (in cm from absolute top of vial)

%% open video

disp('Opening video, please wait.')
vr = VideoReader(video_name);
resolution = [vr.Width vr.Height]; 
nfrm_movie = floor(vr.Duration * vr.FrameRate);

%% define region of interest (ROI)

disp('Click and drag to define region of interest, double-click to proceed.');
figure, imshow(read(vr, 1));
ROI_select = imrect;
ROI = wait(ROI_select); %ROI takes form of [xmin ymin width height]
%close(figure) % doesnt work
disp('ROI selected, proceeding with video analysis.');


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
        %this is the bit that chops the array down to minimum video length.
    %find darkest pixel on image and its coordinates... should be the fly!
    minValue = min(frame_crop(:));
    [ypos, xpos] = find(frame_crop == minValue);
    fr_position = [mean(xpos), mean(ypos), nofr];
    position_array(nofr,:) = fr_position;
end 
%correct position coordinates for ROI operation
position_array = [position_array(:,1) + ROI(1), ...
    position_array(:,2) + ROI(2), ...
    position_array(:,3)];

%% process and output data

%Convert position coordinates to real, meaningful positions (coordinates in
%cm and time in seconds. Scale is in cm/pixels. 
xscale = inner_diameter / ROI(3);
yscale_top = top_half_height / ROI(4); % need to change ROI for second fly
yscale_bottom = bottom_half_height / ROI(4);
corrected_array = [position_array(:,3)/vr.FrameRate, ...
    (position_array(:,1) - ROI(1)) * xscale, ...
    (position_array(:,2) - ROI(2)) * yscale_top,];

disp('Creating output.');
plot(corrected_array(:,2), corrected_array(:,3) + 3)
axis([0 inner_diameter 0 (bottom_half_height + top_half_height)])
% inverts the y coordinates to match the video
set(gca, 'Ydir', 'reverse')

if output == true
%     output_array = num2cell(corrected_array);
%     output_array = vertcat( ...
%     {'Time_s','Fly1_X_pos','Fly1_Y_pos'}, output_array);
    output_array = corrected_array; 
    csvwrite(output_name, output_array);
end

% old code to look at raw position within the image
% plot(position_array(:,1), position_array(:,2))
% axis([0 resolution(1) 0 resolution(2)])
% % inverts the y coordinates to match the video
% set(gca, 'Ydir', 'reverse')