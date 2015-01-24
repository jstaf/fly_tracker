function flytrack_video_fn(video_name, thresholdVal, ...
    filterStatus, filterDist, interpolStatus, interpolDist, ...
    topHeight, bottomHeight, diameter)

%% initialize settings

% A short script to open an image and calculate the position of a fruit fly
% against a light background. Output graph is a sanity check for the path
% of the fly. Written by Jeff Stafford. Some code and ideas from Dan
% Valente's FTrack suite were used, as well as the 'Division' layer mode
% formula from GIMP for background subtraction.

% Key to output csv (fly 1 is on the bottom half of the vial):
% column 1 = Time (in seconds)
% column 2 = Fly 1 x position (in cm from left edge of furthest left ROI)
% column 3 = Fly 1 y position (in cm from absolute top of ROI)
% column 4 = Fly 2 x position
% column 5 = Fly 2 y position

% The size of the area you want to search (in pixels).
search_size = 20;

% The average pixel intensity in the search area must exceed this value to
% log a position and NOT skip the frame. Prevents random noise and other
% weird stuff from "becoming the fly." Essentially requires any given blob
% it detects to be above a certain size and intensity.
per_pixel_threshold = thresholdVal;

% Turn the "teleport filter" on? If the fly position jumps a huge distance
% suddenly, the offending point is erased.
teleportFilt = filterStatus;
% The "huge distance" (in millimeters) that this filter checks for.
% Increase this number if the the program is skipping too many points.
teleDistThreshold = filterDist;
% Number of frames before and after to use as a point of reference.
numAvg = 5;

% Do you want interpolation? If a frame is skipped, this will define a
% fly's position as the average position between current last accepted
% frame and the next "real" frame.
interpolation = interpolStatus;
% This is the maximum distance a fly can move and allow interpolation. The
% default is 0.1 (1 millimeter).
interDistThreshold = interpolDist;

% Default settings for dimensions of assay vial, units in cm. Only change
% if you're using a different via l than normal.
top_half_height = topHeight;
bottom_half_height = bottomHeight;
inner_diameter = diameter;

%% open video

disp(strcat('Opening', {' '}, video_name, ', please wait.'));
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
rotation_angle = -(57.3 * atan((line(1,1) - line(2,1)) / (line(1,2) - line(2,2)) ) );
% Ensure that "point1" is always on top.
if (line(1,2) > line(2,2))
   rotation_angle = rotation_angle + 180;
end
close gcf;

disp('Click and drag to define a rectangular region of interest, double-click to proceed.');
figure('name', 'ROI select'), imshow(imrotate(read(vr, 1), rotation_angle, 'bilinear'));
ROI_select = imrect;
ROI = wait(ROI_select); %ROI takes form of [xmin ymin width height]
close gcf;

%split into 2 ROIs, one for each fly
total_height = top_half_height + bottom_half_height;
ROI_top = ROI;
ROI_top(4) = (top_half_height / total_height) * ROI_top(4);

ROI_bottom = ROI;
ROI_bottom(4) = (bottom_half_height / total_height) * ROI_bottom(4);
ROI_bottom(2) = ROI_bottom(2) + ROI_top(4);

%% create a background

disp('Calculating image background.');

% Pick a random set of 100 frames to create the background.
bg_number = 100;
randv = rand(bg_number,1);
bg_idx = sort(round(randv * nfrm_movie));
%bg_idx = (1:bg_number);

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
background = imrotate(background, rotation_angle, 'bilinear');

%% analyze each frame of the video and subtract background

% pipe settings to terminal 
disp('Settings for analysis:'); 
disp(strcat('Threshold -> ', num2str(thresholdVal)));
disp(strcat('Filter on? -> ', num2str(filterStatus)));
disp(strcat('Filter distance -> ', num2str(filterDist)));
disp(strcat('Interpolation on? -> ', num2str(interpolStatus)));
disp(strcat('Interpolation distance -> ', num2str(interpolDist)));

disp('Calculating fly positions (this part takes awhile...).');

% re-define search parameters to make sense regardless of size
threshold = (search_size)^2 * per_pixel_threshold;
search_size = round(search_size / 2);

%initialize arrays used to log position
bottom_array = zeros(nfrm_movie, 3);
top_array = zeros(nfrm_movie, 3);

%process frames of video for fly
waitDialog = waitbar(0, 'Calculating fly positions');
for nofr = 1:nfrm_movie
    waitbar(nofr/nfrm_movie, waitDialog, ...
        strcat({'Analyzing frame'},{' '}, num2str(nofr), {' '}, {'of'}, {' '}, num2str(nfrm_movie)));
    
    % Extract image from video.
    frame_int = rgb2gray(imrotate(read(vr, nofr), rotation_angle, 'bilinear'));
    
    % Subtract image background using GIMP's image division formula.
    frame_subtracted = uint8((256 * double(frame_int))./(double(background) + 1));
    
    %Bottom ROI processing
    frame_crop = imcrop(frame_subtracted, ROI_bottom);
    fr_position = flyFinder(frame_crop, search_size, threshold);
    bottom_array(nofr,:) = horzcat(nofr, fr_position);
    
    %Top ROI processing
    frame_crop = imcrop(frame_subtracted, ROI_top);
    fr_position = flyFinder(frame_crop, search_size, threshold);
    top_array(nofr,:) = horzcat(nofr, fr_position);
end
close(waitDialog);

%% process and output data

disp('Creating output.');

%Convert position coordinates to real, meaningful positions (coordinates in
%cm and time in seconds. Scale is in cm/pixels.
xscale = inner_diameter / ROI_top(3);
yscale_top = top_half_height / ROI_top(4); % need to change ROI for second fly
yscale_bottom = bottom_half_height / ROI_bottom(4);

%convert to coordinates in cm and frame number to seconds, add coordinate
%offset for bottom fly
corrected_array = [bottom_array(:,1)/vr.FrameRate, ...
    bottom_array(:,2) * xscale, ...
    (bottom_array(:,3) * yscale_bottom) + top_half_height, ...
    top_array(:,2) * xscale, ...
    top_array(:,3) * yscale_top];

skipped1 = sum(isnan(corrected_array(:,2)));
skipped2 = sum(isnan(corrected_array(:,4)));
disp(strcat(num2str(skipped1),{' '}, 'points were skipped out of ' , ...
    num2str(nfrm_movie), {' '},'for fly 1 (bottom).'));
disp(strcat(num2str(skipped2), {' '}, 'points were skipped out of ' , ...
    num2str(nfrm_movie), {' '}, 'for fly 2 (top).'));

% Teleport filter. Removes spurious points where fly position teleports all
% over the vial due to a false track.
if teleportFilt == true
    teleFiltNum = 0;
    for dim = 2:2:4
        for numPoint = (numAvg+1):(nfrm_movie-numAvg)
            point = corrected_array(numPoint, dim:(dim+1));
            if isnan(point) == true
                continue
            else
                % Compute mean positions for last and next numAvg frames.
                lastSet = corrected_array((numPoint - numAvg):(numPoint-1), dim:(dim+1));
                lastSet = lastSet(~isnan(lastSet));
                lastMean = mean(reshape(lastSet, ...
                    [length(lastSet)/2, 2]), 1);
                nextSet = corrected_array((numPoint - numAvg):(numPoint-1), dim:(dim+1));
                nextSet = nextSet(~isnan(nextSet));
                nextMean = mean(reshape(nextSet, ...
                    [length(nextSet)/2, 2]), 1);
                
                % If the fly distance between current and next/last mean
                % positions suddenly moves more than the threshold, remove
                % that point.
                if ((pdist2(point,lastMean) > teleDistThreshold) || ...
                        (pdist2(point,nextMean) > teleDistThreshold))
                    corrected_array(numPoint, dim:(dim+1)) = NaN;
                    teleFiltNum = teleFiltNum + 1;
                end
            end
        end
    end
    disp(strcat(num2str(teleFiltNum), {' '}, 'points removed by the telportation filter.'))
end

% If interpolation == true (set in the settings section above) the script
% will linearly interpolate the flies' position between points as long as
% the fly doesn't move that much (interDistThreshold) between frames.
if (interpolation == true)
    %iterate through datapoints for all four position columns
    interpolationNumber = 0;
    for dim = 2:2:4
        numPoint = 1;
        while numPoint < nfrm_movie
            point = corrected_array(numPoint,dim);
            % If it encounters an NaN, find the last point that was not an NaN
            % and the next point that is not an NaN.
            if ((isnan(point) == true) && (numPoint ~= 1))
                lastIdx = numPoint - 1;
                lastPoint = corrected_array(lastIdx,dim:(dim+1));
                nextIdx = find(~isnan(corrected_array(numPoint:nfrm_movie,dim)) ,1,'first') + numPoint - 1;
                if isempty(nextIdx)
                    break
                end
                nextPoint = corrected_array(nextIdx,dim:(dim+1));
                diff = nextIdx - numPoint;
                
                %check to make sure that the values aren't too far apart to
                %interpolate, then replace bad values!
                interPDist = pdist2(lastPoint,nextPoint);
                if interPDist <= interDistThreshold
                    for badFrameNum =  1:diff
                        corrected_array((lastIdx + badFrameNum),dim:(dim+1)) = ...
                            lastPoint + ( (nextPoint - lastPoint) * badFrameNum/(diff+1));
                    end
                    interpolationNumber = interpolationNumber + diff;
                end
                
                % Keep track of how many frames we've interpolated and skip
                % to next non-NaN value.
                numPoint = nextIdx;
                
            elseif ((isnan(point) == true) && (numPoint == 1))
                numPoint = find(~isnan(corrected_array(:,dim)), 1,'first');
            else
                numPoint = numPoint + 1;
            end
        end
    end
    disp(strcat(num2str(interpolationNumber), {' '}, 'points recovered through interpolation.'))
end

skippedEnd = sum(sum(isnan(corrected_array(:,[2,4]))));
disp(strcat({'In total,'},{' '}, num2str(skippedEnd),{' '}, {'points were not recorded out of'} , {' '}, num2str(nfrm_movie * 2), {'.'}));

% create a new figure and plot fly path
figure('Name','Fly pathing map');
plot(corrected_array(:,2), corrected_array(:,3), ...
    corrected_array(:,4), corrected_array(:,5))
axis([0 inner_diameter 0 (bottom_half_height + top_half_height)], 'equal', 'manual')
xlabel('X-coordinate (cm)', 'fontsize', 11)
ylabel('Y-coordinate (cm)', 'fontsize', 11)
legend('Fly 1 (bottom)', 'Fly 2 (top)', 'location', 'southoutside')
% inverts the y coordinates to match the video
set(gca, 'Ydir', 'reverse')

% write output
[output_name,path] = uiputfile('.csv');
output_array = corrected_array;
if output_name ~= 0  % in case someone closes the file saving dialog
    csvwrite(strcat(path,output_name), output_array);
else
    disp('File saving cancelled.')
end

return;