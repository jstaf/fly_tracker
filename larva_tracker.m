%% initialize settings

% Controls how far apart the frames we are analyzing. Setting 'fs' to 15
% means that every 15 frames are analyzed out of our video.
fs = 15;

sizeThresh = 25;

% A decimal value used during background subtraction. A typical value would
% be from -0.1 to 0.1. Can be negative. The higher this value, the more
% severely objects are thresholded.
threshOffset = 0;

% Diameter of the circular arena we are using (in cm).
arenaSize = 8.5;

% Don't touch this variable for now.
numLarvae = 1;

%% open video

[video_name, pathname] = uigetfile({'*.avi;*.mj2;*.mpg;*.mp4;*.m4v;*.mov', ...
    'Video Files (*.avi;*.mj2;*.mpg;*.mp4;*.m4v;*.mov)'}, ...
    'Select a video to analyze...', 'MultiSelect','off');
if (pathname ~= 0)
    video_name = strcat(pathname,video_name);
else
    break;
end

disp(strcat('Opening', {' '}, video_name, ', please wait.'));
vr = VideoReader(video_name);
resolution = [vr.Width vr.Height];
nfrm_movie = floor(vr.Duration * vr.FrameRate);

% define region of interest (ROI) 
disp('Click and drag to define a rectangular region of interest, double-click to proceed.');
figure('name', 'ROI select'), imshow(read(vr, 1));
ROI_select = imrect;
ROI = round(wait(ROI_select)); %ROI takes form of [xmin ymin width height]
close gcf;
if isempty(ROI)
    break;
end

%% create a background

% Pick a random set of 100 frames to create the background.
bg_number = 100;
randv = rand(bg_number,1);
bg_idx = sort(round(randv * nfrm_movie));

% Read each frame of the background and average them to create a background
% image.
bg_array = zeros(resolution(2), resolution(1), bg_number, 'uint8');
for bg_step = 1:bg_number
    bg_frame = rgb2gray(read(vr, bg_idx(bg_step)));
    bg_array(:,:,bg_step) = bg_frame;
end
background =  uint8(mean(bg_array, 3));
background = imcrop(background, ROI);

%% create a binary map from each frame

%process frames of video for fly
binaryMap = false(ROI(4)+1, ROI(3)+1 ,ceil(nfrm_movie/fs));
waitDialog = waitbar(0, 'Creating binary maps from video...');
for nofr = 1:fs:nfrm_movie
    waitbar(nofr/nfrm_movie, waitDialog, ...
        strcat({'Creating binary maps from frame'},{' '}, num2str(nofr), {' '}, {'of'}, {' '}, num2str(nfrm_movie)));
    
    % Extract image from video. 
    frame = imcrop(rgb2gray(read(vr, nofr)), ROI);
    
    % Subtract image background.
    frame = frame - background; 
    
    % Threshold image.
    thresh = graythresh(frame) + threshOffset; % otsu's method + an offset
    if (thresh < 0)
        thresh = 0.01;
    end
    frame_thresh = medfilt2(im2bw(frame, thresh));
    
    % Check to see if the threshold is too high/low, recalculate frame with
    % different threshold if yes.
    check = regionprops(frame_thresh, 'Area');
    if (length([check.Area]) > numLarvae + 5)
        thresh = thresh + 0.15;
        frame_thresh = medfilt2(im2bw(frame, thresh));
    elseif (length([check.Area]) < numLarvae)
        thresh = thresh - 0.05;
        if (thresh < 0)
            thresh = 0.01;
        end
        frame_thresh = medfilt2(im2bw(frame, thresh));
    end
    
    % Dump image to binaryVideo for later separation
    binaryMap(:,:,ceil(nofr/fs)) = frame_thresh;
end
close(waitDialog);

%% label and analyze binary maps

position = zeros(ceil(nfrm_movie/fs), numLarvae*2);

waitDialog = waitbar(0, 'Analyzing maps...');
binaryLabel = zeros(size(binaryMap), 'uint8');
arraysz = size(binaryMap,3);
for nofr = 1:arraysz
    waitbar(nofr/arraysz, waitDialog, ...
        strcat({'Analyzing map'},{' '}, num2str(nofr), {' '}, {'of'}, {' '}, num2str(arraysz)));
    
    % label regions and compute region properties
    binaryLabel(:,:,nofr) = bwlabel(binaryMap(:,:,nofr),4);
    regions = regionprops(binaryLabel(:,:,nofr),'Area', 'Centroid', 'PixelList');
    
    % small regions (not larvae) are filtered out of our data
    regionNum = 1;
    while (regionNum <= length([regions.Area]))
        % arbitrary threshold- larvae are about twice this size
        if (regions(regionNum).Area < sizeThresh) 
            % unlabel piimellipsexels in small regions
            for pixRow = 1:size(regions(regionNum).PixelList,1);
                binaryLabel( ...
                    regions(regionNum).PixelList(pixRow,2), ...
                    regions(regionNum).PixelList(pixRow,1), nofr) ...
                    = 0;
            end
            % now delete the entry
            regions(regionNum) = []; 
        else
            regionNum = regionNum + 1;
        end
    end
    
    % re-count and label regions
    regionsLength = length([regions.Area]);
    if (nofr == 1)
        % sort regions by euclidean distance to (0,0)
        for i = 1:regionsLength
            regions(i).DistToOrigin = sqrt(regions(i).Centroid(1)^2 + regions(i).Centroid(2)^2);
        end
        if ~isempty(regions)
            [temp, idx] = sort([regions.DistToOrigin]);
            regions = regions(idx);
            skip = false;
        end
    else
        % sort regions based on proximity to last labeled regions
        for i = 1:length([regions.Area])
            % create a vector of dists, ordered from 1:(all of lastRegion's regions)
            dist = zeros(1,length([lastRegions.Area]));
            for j = 1:length([lastRegions.Area])
                dist(j) = pdist2(regions(i).Centroid, lastRegions(j).Centroid);
            end
            % which region centroid matches the last's most closely?
            [minDist, idx] = min(dist);
            regions(i).lastLabelIdx = idx;
        end
        
        if (~isempty(regions))
            [temp, idx] = sort([regions.lastLabelIdx]);
            regions = regions(idx);
        end
    end
    
    
    if length([regions.Area]) < numLarvae % if missing larvae
        % TODO find regions larger than larva are supposed to be
        % count those regions twice or subtract last frame
        %largestRegion = 
        
        %create duplicate regions if the numRegions is less than last frame

        skip = true;
%         if regionsLength < length([lastRegions.Area])
%             % two larva just touched last frame
%         end
    elseif length([regions.Area]) > numLarvae % we've likely picked up noise
        % TODO pick the areas closest to last size and position
        % areas furthest from last size should be last in our sorted
        % regions1:numLarvae
        
        % delete all of the "last" regions in the list, (these are furthest
        % from current larvae)
        reg = (numLarvae+1);
        while (reg < length([regions.Area]))
            % unlabel pixels
            for pixRow = 1:size(regions(reg).PixelList,1);
                binaryLabel( ...
                    regions(reg).PixelList(pixRow,2), ...
                    regions(reg).PixelList(pixRow,1), nofr) ...
                    = 0;
            end
         binaryLabel = zeros(size(binaryMap), 'uint8');
   % now delete the entry
            regions(reg) = []; 
        end
    end
    
    % change the value of every labeled pixel to the new value (based on
    % sort order)
    for newLabel = 1:length([regions.Area])
        for pixRow = 1:size(regions(newLabel).PixelList,1);
            binaryLabel( ...
                regions(newLabel).PixelList(pixRow,2), ...
                regions(newLabel).PixelList(pixRow,1), nofr) ...
                = newLabel; % change the label to the last label
        end
    end
    
    % extract positions
    if (skip)
        position(ceil(nofr/fs),:) = NaN; %placeholder
        skip = false;
    else
        centroid = [regions.Centroid]';
        for larva = 1:numLarvae
            position(nofr, (larva*2-1):(larva*2)) = centroid((larva*2-1):(larva*2));
        end
    end
    
    % store 'regions' regionProps data for next loop iteration
    lastRegions = regions;
end
close(waitDialog);

%% convert positions to meaningful coordinates and plot

xscale = arenaSize / ROI(3);
yscale = arenaSize / ROI(4);
scaledPos = position;
for column = 1:size(position,2)
    if (mod(column,2) == 1) % odd column
        scaledPos(:,column) = position(:,column)*xscale;
    else % even column
        scaledPos(:,column) = position(:,column)*yscale;
    end
end
scaledPos = horzcat( ((0:fs:(nfrm_movie-1))/round(vr.FrameRate))', scaledPos);
% correct spurious points
scaledPos = distFilter(scaledPos, 0.5);
if (0.25 < pdist2(scaledPos(1,1:2), scaledPos(2,1:2))) % a bit placeholder-y
    scaledPos(1,1:2) = NaN;
end
scaledPos = interpolatePos(scaledPos, 0.05);

figure('Name','Pathing map');
lineColor = ['b','g','r','c','m','y'];
hold on;
for i = 2:2:size(scaledPos,2)-1
    plot(scaledPos(:,i), scaledPos(:,i+1), lineColor(mod(i/2,6)));
end
hold off;
xlabel('X-coordinate (cm)', 'fontsize', 11);
ylabel('Y-coordinate (cm)', 'fontsize', 11);
axis([0 arenaSize 0 arenaSize], 'equal', 'manual')
% inverts the y coordinates to match the video
set(gca, 'Ydir', 'reverse');

%% write positions to disk

[output_name,path] = uiputfile('.csv');
if output_name ~= 0  % in case someone closes the file saving dialog
    csvwrite(strcat(path,output_name), scaledPos);
else
    disp('File saving cancelled.')
end
