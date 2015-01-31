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

%% create a binary map from each frame

%process frames of video for fly
binaryMap = false(ROI(4)+1, ROI(3)+1 ,nfrm_movie);
waitDialog = waitbar(0, 'Creating binary maps from video...');
for nofr = 1:nfrm_movie
    waitbar(nofr/nfrm_movie, waitDialog, ...
        strcat({'Creating binary maps from frame'},{' '}, num2str(nofr), {' '}, {'of'}, {' '}, num2str(nfrm_movie)));
    
    % Extract image from video.
    frameInt = rgb2gray(read(vr, nofr));
    frame = imcrop(frameInt, ROI);
    
    % Subtract image background.
    frame = frame - background;
    
    % Threshold image.
    thresh = graythresh(frame);
    frame = medfilt2(im2bw(frame, thresh));
    
    % Dump image to binaryVideo for later separation
    binaryMap(:,:,nofr) = frame;
end
close(waitDialog);

%% label and analyze binary maps

numLarvae = 5;
position = zeros(nfrm_movie, numLarvae);

waitDialog = waitbar(0, 'Analyzing maps...');
binaryLabel = zeros(size(binaryMap), 'uint8');
for nofr = 1:nfrm_movie
    waitbar(nofr/nfrm_movie, waitDialog, ...
        strcat({'Analyzing map'},{' '}, num2str(nofr), {' '}, {'of'}, {' '}, num2str(nfrm_movie)));
    
    % label regions and compute region properties
    binaryLabel(:,:,nofr) = bwlabel(binaryMap(:,:,nofr),4);
    stat = regionprops(binaryLabel(:,:,nofr),'Area', 'Centroid');
    
    checkNum = length([stat.Area]);
    if checkNum < numLarvae % if missing larvae
        % TODO find regions larger than larva are supposed to be
        position(nofr,:) = NaN; %placeholder
    elseif checkNum > numLarvae % we've likely picked up noise
        % TODO pick the largest areas
        position(nofr,:) = NaN; %placeholder!
    else
        % Need to sort by proximity to origin, and check for proximity to
        % last frame, THEN extract centroids
        centroid = [stat.Centroid]';
        for larva = 1:checkNum
            position(nofr, (larva*2-1):(larva*2)) = centroid((larva*2-1):(larva*2));
        end
    end
end
close(waitDialog);

%% create a video for debugging

% reformat data
videoOut = uint8(binaryMap);
videoOut = videoOut*255;

writer = VideoWriter('larva_debug.avi');
writer.FrameRate = vr.FrameRate;
% writer.VideoFormat = 'Grayscale';
open(writer);
preFrame = zeros(ROI(4)+1, ROI(3)+1, 'uint8');
for nofr = 1:nfrm_movie
    for channel = 1:3
        preFrame(:,:,channel) = videoOut(:,:,nofr);
    end
    videoFrame = im2frame(preFrame);
    writeVideo(writer, videoFrame);
    
end
close(writer);

%% process and output data

disp('Creating output.');

%Convert position coordinates to real, meaningful positions (coordinates in
%cm and time in seconds. Scale is in cm/pixels.
xscale = inner_diameter / ROI_top(3);
yscale = inner_diameter / ROI_top(4); % need to change ROI for second fly

%convert to coordinates in cm and frame number to seconds, add coordinate
%offset for bottom fly
corrected_array = position; % placeholder

% corrected_array = [position(:,1)/vr.FrameRate, ...
%     position(:,2) * xscale, ...
%     (position(:,3) * yscale);

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

if output_name ~= 0  % in case someone closes the file saving dialog
    csvwrite(strcat(path,output_name), corrected_array);
else
    disp('File saving cancelled.')
end
