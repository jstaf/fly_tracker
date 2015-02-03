%% initialize settings

video_name = 'IMGP0521.AVI';
numLarvae = 5;

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
    thresh = graythresh(frame) + 0.025; % otsu's method + an offset
    frame_thresh = medfilt2(im2bw(frame, thresh));
    
    % Check to see if the threshold is too low, recalculate frame with
    % higher threshold if yes.
    check = regionprops(frame_thresh, 'Area');
    if length([check.Area]) > (numLarvae + 10)
        thresh = thresh + 0.15;
        frame_thresh = medfilt2(im2bw(frame, thresh));
    end
    
    % Dump image to binaryVideo for later separation
    binaryMap(:,:,nofr) = frame_thresh;
end
close(waitDialog);

%% label and analyze binary maps

position = zeros(nfrm_movie, numLarvae);

waitDialog = waitbar(0, 'Analyzing maps...');
binaryLabel = zeros(size(binaryMap), 'uint8');
for nofr = 1:nfrm_movie
    waitbar(nofr/nfrm_movie, waitDialog, ...
        strcat({'Analyzing map'},{' '}, num2str(nofr), {' '}, {'of'}, {' '}, num2str(nfrm_movie)));
    
    % label regions and compute region properties
    binaryLabel(:,:,nofr) = bwlabel(binaryMap(:,:,nofr),4);
    regions = regionprops(binaryLabel(:,:,nofr),'Area', 'Centroid', 'PixelList');
    
    % small regions (not larvae) are filtered out of our array
    regionNum = 1;
    while regionNum < length([regions.Area])
        % arbitrary threshold- larvae are about twice this size
        if (regions(regionNum).Area < 40) 
            regions(regionNum) = [];
        else
            regionNum = regionNum + 1;
        end
    end
    
    % relabel regions
    regionsLength = length([regions.Area]);
    if (nofr == 1)
        % sort regions by euclidean distance to (0,0)
        for i = 1:regionsLength
            regions(i).DistToOrigin = sqrt(regions(i).Centroid(1)^2 + regions(i).Centroid(2)^2);
        end
        [temp, idx] = sort([regions.DistToOrigin]);
        regions = regions(idx);
    else
        % sort regions based on proximity to last labeled regions
        for i = 1:regionsLength
            % create a vector of dists, ordered from 1:(all of lastRegion's regions)
            dist = zeros(1,length([lastRegions.Area]));
            for j = 1:length([lastRegions.Area])
                dist(j) = pdist2(regions(i).Centroid, lastRegions(j).Centroid);
            end
            % which region centroid matches the last's most closely?
            [tmp, idx] = min(dist);
            regions(i).lastLabelDists = idx;
        end
        [temp, idx] = sort([regions.lastLabelDists]);
        regions = regions(idx);
    end
    
    % change the value of every labeled pixel to the new value (based on
    % sort order)
    for newLabel = 1:regionsLength
        for pixRow = 1:size(regions(newLabel).PixelList,1);
            binaryLabel( ...
                regions(newLabel).PixelList(pixRow,2), ...
                regions(newLabel).PixelList(pixRow,1), nofr) ...
                = newLabel;
            % might have indexed this wrong!!!!!!!!! CHECK ME!!!!!
        end
    end
    
%     if regionsLength < numLarvae % if missing larvae
%         % TODO find regions larger than larva are supposed to be
%         % count those regions twice or subtract last frame
%         position(nofr,:) = NaN; %placeholder
%     elseif regionsLength > numLarvae % we've likely picked up noise
%         % TODO pick the areas closest to last size and position
%         % areas furthest from last size should be last in our sorted
%         % regions
%         position(nofr,:) = NaN; %placeholder!
%     else
%         % Need to sort by proximity to origin, and check for proximity to
%         % last frame, THEN extract centroids
%         centroid = [regions.Centroid]';
%         for larva = 1:checkNum
%             position(nofr, (larva*2-1):(larva*2)) = centroid((larva*2-1):(larva*2));
%         end
%     end
    
    % store 'regions' regionProps data for next loop iteration
    lastRegions = regions;
end
close(waitDialog);

%% create a video for debugging

% generate colors
% maximum = max(binaryLabel(:));
maximum = max(test(:));
colorMap = zeros(maximum, 3);
for i = 1:maximum
    val = double(i)/double(maximum);
    % r channel
    colorMap(i,1) = ceil(255*val);
    % g channel
    if val < 0.5
        colorMap(i,2) = ceil(255*val*2);
    else
        colorMap(i,2) = 255 - ceil(255*(val-0.5)*2);
    end
    % b channel
    colorMap(i,3) = 255 - ceil(255*val);
end
% randomize colormap for more variety
randomIdx = randperm(maximum);
colorMap = colorMap(randomIdx, :);

% add color data to show labeling
blSize = size(binaryLabel);
movieFrames = zeros(blSize(1), blSize(2), 3, blSize(3), 'uint8');
waitDialog = waitbar(0, 'Creating video...');
for nofr = 1:blSize(3)
    waitbar(nofr/nfrm_movie, waitDialog, ...
        strcat({'Creating frame'},{' '}, num2str(nofr), {' '}, {'of'}, {' '}, num2str(nfrm_movie)));
    for channel = 1:3
        movieFrames(:,:,channel,nofr) = binaryLabel(:,:,nofr);
        %testFrame(:,:,channel) = test;
        for color = 1:maximum
            % next line needs an indexing fix
            tmp = movieFrames(:,:,channel,nofr);
            tmp(tmp == color) = colorMap(color,channel);
            movieFrames(:,:,channel,nofr) = tmp;
            
%             tmp = testFrame(:,:,channel);
%             tmp(tmp == color) = colorMap(color,channel);
%             testFrame(:,:,channel) = tmp;
        end
    end
end

writer = VideoWriter('larvaDebug_tracking.avi');
writer.FrameRate = vr.FrameRate;
open(writer);
for nofr = 1:nfrm_movie
    waitbar(nofr/nfrm_movie, waitDialog, ...
        strcat({'Writing frame'},{' '}, num2str(nofr), {' '}, {'of'}, {' '}, num2str(nfrm_movie)));
    writeVideo(writer, im2frame(movieFrames(:,:,:,nofr)));
    
end
close(writer);
close(waitDialog);


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
