%% initialize settings

% This script loads position data from the flytrack_video script, collapses
% data from multiple replicates, and makes a heatmap of where the flies went. 

% Jeff Stafford

% How long is the assay (in seconds)? If one of the csv files is shorter
% than this, defaults to the shorter time.
total_time = 120;

% This is the size of the squares used for binning in the heatmap.
binSize = 0.2;

% What interval do wish to bin positions at? The flies' position will be
% used every <binRate> seconds.
binRate = 0.033;

%input dimensions of assay vial, units in cm
height = 8;
width = 8;

%% read files 

[file_list, pathname] = uigetfile({'*.csv', ...
    'Positon Files (*.csv)'}, ...
    'Select files with positions to analze...', 'MultiSelect','on');
file_list = strcat(pathname, file_list);
num_files = size(file_list, 2);

%% assemble into array

% Iterates through every row of each file and adds it to "rep_combined"
% array as long as there is video remaining. If video runs out of frames
% for any replicate, chops length of all videos to minimum video length.
total_frames = ceil(total_time / binRate);
rep_combined = zeros(total_frames, 3, num_files);
rep_combined(:) = NaN;
for i = 1:num_files
    replicate = csvread(char(file_list(i)));
    
    framerate = round(1 / (replicate(2, 1) - replicate(1, 1)));
    step = round(binRate * framerate);
    
    toReplace = length(1:step:length(replicate(:, 1)));
    rep_combined(1:toReplace, :, i) = replicate(1:step:end, :);
    
    %this is the bit that chops the array down to minimum video length.
    if size(replicate, 1) < size(rep_combined, 1);
        rep_combined = rep_combined(1:size(replicate, 1), :, :);
    end
end

% reshape rep_combined into reallllly long array
combined = zeros(size(rep_combined, 1) * num_files, 2);
rep_length = size(rep_combined, 1);
last = 1;
for j = 1:num_files
    combined(last:(last + rep_length - 1), :) = rep_combined(:, 2:3, j);
    last = last + rep_length;
end

% remove NaNs
combined = combined(~isnan(combined(:,1)), :);
% all coordinates exceeding vial bounds are reduced to what is actually possible within the vial.
if (any(combined(:,1) > width))
   combined(combined(:,1) > width, 1) = width; 
end
if (any(combined(:,2) > height))
   combined(combined(:,2) > height, 2) = height; 
end

%% START BINNING!!! 

% convert everything to 1mm x 1mm "position coordinate" bins
[xnum, xbinCount] = histc(combined(:,1), linspace(0, width, (width / binSize) + 1));
[ynum, ybinCount] = histc(combined(:,2), linspace(0, height, (height / binSize) + 1));
bin_matrix = full(sparse(ybinCount, xbinCount, 1));

% The full matrix will be missing rows if the fly did not go to the
% lower-right most corner (due to the "sparse" trick). Now add those back in.
matSize = size(bin_matrix);
missingSize = [height / binSize, width / binSize] - matSize;
bin_matrix = vertcat(bin_matrix, zeros(missingSize(1), matSize(2)));
bin_matrix = horzcat(bin_matrix, zeros(height / binSize, missingSize(2)));
% now convert to log(probability)
bin_matrix = log(bin_matrix ./ size(combined, 1)); % numRows is the total number of data points in fly_combined as defined above

%% plot heatmap

figure('Name', 'Position heatmap');

heatXLab = binSize:binSize:width;
heatYLab = binSize:binSize:height;

posMap = heatmap(bin_matrix, heatXLab, heatYLab, [], ...
    'Colormap', 'hot', 'Colorbar', true);
%axis([0 width*10 0 total_height*10]);
axis('equal', 'manual');
xlabel('X-coordinate (cm)', 'fontsize', 11)
ylabel('Y-coordinate (cm)', 'fontsize', 11)

