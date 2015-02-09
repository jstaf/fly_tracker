%% initialize settings

video_name = 'IMGP0271.AVI';

% A decimal value used during background subtraction. A typical value would
% be from -0.1 to 0.1. Can be negative.
threshOffset = 0;

% Diameter of the circular arena we are using.
arenaSize = 6;

numLarvae = 1;

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
    thresh = graythresh(frame) + threshOffset; % otsu's method + an offset
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
%unfilteredLabel = binaryLabel;
for nofr = 1:nfrm_movie
    waitbar(nofr/nfrm_movie, waitDialog, ...
        strcat({'Analyzing map'},{' '}, num2str(nofr), {' '}, {'of'}, {' '}, num2str(nfrm_movie)));
    
    % label regions and compute region properties
    binaryLabel(:,:,nofr) = bwlabel(binaryMap(:,:,nofr),4);
    regions = regionprops(binaryLabel(:,:,nofr),'Area', 'Centroid', 'PixelList');
    
    % store information for debugging
    % unfilteredLabel(:,:,nofr) = binaryLabel(:,:,nofr);
    
    % small regions (not larvae) are filtered out of our data
    regionNum = 1;
    while (regionNum < length([regions.Area]))
        % arbitrary threshold- larvae are about twice this size
        if (regions(regionNum).Area < 40) 
            % unlabel pixels in small regions
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
        [temp, idx] = sort([regions.DistToOrigin]);
        regions = regions(idx);
        skip = false;
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
                = newLabel; % change the label to the last label
        end
    end
    
    if regionsLength < numLarvae % if missing larvae
        % TODO find regions larger than larva are supposed to be
        % count those regions twice or subtract last frame
        skip = true;
%         if regionsLength < length([lastRegions.Area])
%             % two larva just touched last frame
%         end
    elseif regionsLength > numLarvae % we've likely picked up noise
        % TODO pick the areas closest to last size and position
        % areas furthest from last size should be last in our sorted
        % regions
        
        % delete all of the "last" regions in the list, (these are furthest
        % from current larvae)
        for reg = (numLarvae+1):regionsLength
            % unlabel pixels
            for pixRow = 1:size(regions(reg).PixelList,1);
                binaryLabel( ...
                    regions(reg).PixelList(pixRow,2), ...
                    regions(reg).PixelList(pixRow,1), nofr) ...
                    = 0;
            end
            % now delete the entry
            regions(reg) = []; 
        end
    end
    
    % extract positions
    if (~skip)
        centroid = [regions.Centroid]';
        for larva = 1:numLarvae
            position(nofr, (larva*2-1):(larva*2)) = centroid((larva*2-1):(larva*2));
        end
    else
        position(nofr,:) = NaN; %placeholder
    end
    
    skip = false;
    % store 'regions' regionProps data for next loop iteration
    lastRegions = regions;
end
close(waitDialog);

%% show number of tracked objects over time

numberTracked = zeros(nfrm_movie,1, 'uint8');
%numberUnfiltered = numberTracked;
for nofr = 1:nfrm_movie
    numberTracked(nofr) = max(max(binaryLabel(:,:,nofr)));
    %numberUnfiltered(nofr) = max(max(unfilteredLabel(:,:,nofr)));
end
figure('Name','Tracking Quality');
plot(1:nfrm_movie, numberTracked, ... %    1:nfrm_movie, numberUnfiltered, ...
    1:nfrm_movie, numLarvae);
xlabel('Frame number');
ylabel('# objects tracked');
legend('Processed data', 'Raw data', 'Actual number', ...
    'location', 'NorthWest');

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

figure('Name','Pathing map');
hold on;
for i = 2:2:size(scaledPos,2)
    plot(scaledPos(:,i-1), scaledPos(:,i));
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
    csvwrite(strcat(path,output_name), position);
else
    disp('File saving cancelled.')
end

