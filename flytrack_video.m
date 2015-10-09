%% initialize settings

% A short script to open an image and calculate the position of a fruit fly
% against a light background. Output graph is a sanity check for the path
% of the fly. Written by Jeff Stafford. Some code and ideas from Dan
% Valente's FTrack suite were used, as well as the 'Division' layer mode
% formula from GIMP for background subtraction.

% Key to output csv
% column 1 = Time (in seconds)
% column 2 = Fly 1 x position (in cm from left edge of furthest left ROI)
% column 3 = Fly 1 y position (in cm from absolute top of ROI)

% The size of the area you want to search (in pixels).
search_size = 20;

% The average pixel intensity in the search area must exceed this value to
% log a position and NOT skip the frame. Prevents random noise and other
% weird stuff from "becoming the fly." Essentially requires any given blob
% it detects to be above a certain size and intensity.
per_pixel_threshold = 1.5;

% Default settings for dimensions of assay vial, units in cm. Only change
% if you're using a different via l than normal.
height = 8;
width = 8;

%% open video

[video_name, pathname] = uigetfile({'*.avi;*.mj2;*.mpg;*.mp4;*.m4v;*.mov', ...
    'Video Files (*.avi;*.mj2;*.mpg;*.mp4;*.m4v;*.mov)'}, ...
    'Select a video to analyze...', 'MultiSelect','off');
video_name = [pathname, video_name];

disp(['Opening ', video_name, ', please wait.']);
vr = VideoReader(video_name);
resolution = [vr.Width vr.Height];
nfrm_movie = floor(vr.Duration * vr.FrameRate) - 1;

%% define region of interest (ROI)

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

%% analyze each frame of the video and subtract background

disp('Calculating fly positions (this part takes awhile...).');

% re-define search parameters to make sense regardless of size
threshold = (search_size)^2 * per_pixel_threshold;
search_size = round(search_size / 2);

%initialize arrays used to log position
pos_array = zeros(nfrm_movie, 3);

%process frames of video for fly
waitDialog = waitbar(0, 'Calculating fly positions');
for nofr = 1:nfrm_movie
    waitbar(nofr/nfrm_movie, waitDialog, ...
        ['Analyzing frame ', num2str(nofr), ' of ',num2str(nfrm_movie)]);
    
    % Extract image from video.
    frame_int = uint8(rgb2gray(read(vr, nofr)));
    
    % Subtract image background using GIMP's image division formula.
    frame_int = uint8((256 * double(frame_int))./(double(background) + 1));
    
    % Find the fly
    frame_crop = imcrop(frame_int, ROI);
    fr_position = flyFinder(frame_crop, search_size, threshold, true);
    % nofr - 1 is for zero based numbering, like the larva tracker
    pos_array(nofr,:) = [nofr - 1, fr_position]; 
end
close(waitDialog);

%% process and output data

disp('Creating output.');

%Convert position coordinates to real, meaningful positions (coordinates in
%cm and time in seconds. Scale is in cm/pixels.
xscale = width / ROI(3);
yscale = height / ROI(4);

%convert to coordinates in cm and frame number to seconds, add coordinate
%offset for bottom fly
corrected_array = [pos_array(:,1)/vr.FrameRate, ...
    pos_array(:,2) * xscale, ...
    (pos_array(:,3) * yscale)];

skipped = sum(isnan(corrected_array(:,2)));
disp([num2str(skipped), ' points were skipped out of ', num2str(nfrm_movie),' for fly 1.']);

% Teleport filter. Removes spurious points where fly position teleports all
% over the vial due to a false track.
if true
  corrected_array = distFilter(corrected_array, 2);
end
if (true)
    corrected_array = interpolatePos(corrected_array, 2);
end

% create a new figure and plot fly path
figure('Name','Pathing map');
x = corrected_array(:,2)';
y = corrected_array(:,3)';
z = zeros(size(x));
col = corrected_array(:,1)'; 
surface([x;x],[y;y],[z;z],[col;col],...
        'facecol','no',...
        'edgecol','interp',...
        'linew',2, ...
        'LineSmoothing','on');
xlabel('X-coordinate (cm)', 'fontsize', 11);
ylabel('Y-coordinate (cm)', 'fontsize', 11);
axis('manual', 'equal');
axis([0 width 0 height]);
% inverts the y coordinates to match the video
set(gca, 'Ydir', 'reverse');

%% write output
[output_name,path] = uiputfile('.csv');
output_array = corrected_array;
if output_name ~= 0  % in case someone closes the file saving dialog
    csvwrite(strcat(path,output_name), output_array);
else
    disp('File saving cancelled.')
end

return;