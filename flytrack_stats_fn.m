function flytrack_stats_fn(file_list, assayTime, framerateSet, noflyBool, noflyPos)

%% initialize settings

% This script loads output data from the flytrack_video script, collapses
% data from multiple replicates, and performs a bit of visualization. 

% Jeff Stafford

% File list to load. Write the names of the files you want to load here in
% a comma delimited list. THEY MUST ALL BE IN THE WORKING DIRECTORY OF THIS
% SCRIPT OR IT WON'T WORK AND YOU WILL BE SAD.
%file_list = {'WTmale4_nofly1_nov23.csv'};
%interflyDistanceFilename = 'name your file here.csv';

% Is a fly missing from either the top or bottom? Used as a "no fly"
% control. Type 'top' if the top fly is missing, and 'bottom' if the bottom
% fly is missing. You can type absolute gibberish otherwise.
noFlyOn = noflyBool;
noFly = noflyPos;

% How long is the assay (in seconds)? If one of the csv files is shorter
% than this, defaults to the shorter time.
total_time = assayTime;

% What was your framerate? The Pentax cameras we use can capture at either 15 or 30 fps.
framerate = framerateSet;

%input dimensions of assay vial, units in cm
top_half_height = 3;
bottom_half_height = 8;
inner_diameter = 1.5;

total_height = top_half_height + bottom_half_height;

%% read files and assemble into array

num_files = size(file_list);
num_files = num_files(2);
disp(strcat(num2str(num_files), ' files selected for analysis.'));

disp('Loading files...');
% Iterates through every row of each file and adds it to "rep_combined"
% array as long as there is video remaining. If video runs out of frames
% for any replicate, chops length of all videos to minimum video length.
total_frames = total_time * framerate;
rep_combined = zeros(total_frames, 5, num_files);
for index = 1:num_files
    replicate = csvread(char(file_list(index)));
    num_rows = size(replicate);
    num_rows = num_rows(1);
    row = 1;
    while (row <= num_rows) && (row <= total_frames)
        rep_combined(row,:,index) = replicate(row,:);
        row = row + 1;
    end
    %this is the bit that chops the array down to minimum video length.
    array_length = size(rep_combined);
    array_length = array_length(1);
    if num_rows < array_length
        rep_combined = rep_combined(1:num_rows,:,:);
    end
end

% reshape rep_combined into reallllly long array
array_size = size(rep_combined);
rep_combined_lg = zeros(array_size(1) * num_files, 5);
if num_files == 1
    rep_combined_lg = rep_combined;
else
    for dim = 1:array_size(3)
        row = 1;
        while row <= array_size(1)
            rep_combined_lg(row + ((dim - 1) * array_size(1)),:) = rep_combined(row,:,dim);
            row = row + 1;
        end
    end
end

%% calculate interfly distance for individual video replicates

interfly_distanceRep = zeros([size(rep_combined, 1), size(rep_combined, 3)]);
for dim = 1:size(rep_combined, 3)
    for row = 1:size(rep_combined, 1)
        if noFlyOn
            if strcmp(noFly,'top')
                interfly_distanceRep(row,dim) = pdist2(rep_combined(row,2:3,dim), [inner_diameter/2, top_half_height]);
            elseif strcmp(noFly,'bottom')
                interfly_distanceRep(row,dim) = pdist2([inner_diameter/2, top_half_height], rep_combined(row,4:5,dim));
            else
                disp('Something went wrong, analyzing data for two flies');
                interfly_distanceRep(row,dim) = pdist2(rep_combined(row,2:3,dim), rep_combined(row,4:5,dim));
            end
        else
            interfly_distanceRep(row,dim) = pdist2(rep_combined(row,2:3,dim), rep_combined(row,4:5,dim));
        end
    end
end

% Write a file with the interfly distance for each replicate. 
[interflyDistanceFilename,path] = uiputfile;
try % in case someone closes the file saving dialog
    csvwrite(strcat(path,interflyDistanceFilename), interfly_distanceRep);
catch
    disp('File saving cancelled.')
end

% Reshape into a long array for plotting. numRows also can be used for the
% total number of points being analyzed.
numRows = size(interfly_distanceRep,1)*size(interfly_distanceRep,2);
interfly_distance = reshape(interfly_distanceRep,numRows,1);
interfly_idx = find(isnan(interfly_distance) == false);
interfly_distance = interfly_distance(interfly_idx);

%% plot interfly distance

figure('Name', 'Interfly Distance');

% what's the farthest the flies can be apart? Rounded up to nearest
% millimeter.
maxdist = ceil(sqrt(total_height^2 + inner_diameter^2)*10)/10;
binDefinition = linspace(0,maxdist, maxdist*10)';

% bin interfly distance for all replicates
[distNum, distBins] = histc(interfly_distance, binDefinition);
distNum = distNum/numRows;
interflyDistanceData = [binDefinition, distNum];
plot(distNum);
xlabel('Interfly distance (mm)', 'fontsize', 11);
ylabel('Probability', 'fontsize', 11);

%% bin positions for heatmapping

% dump fly 1 and fly 2 into a common array, remove NaN's
fly_combined = vertcat(rep_combined_lg(:,2:3), rep_combined_lg(:,4:5));
fly_combined = fly_combined(isfinite(fly_combined(:,1)),:);

% all coordinates exceeding vial bounds are reduced to what is actually possible within the vial.
if (any(fly_combined(:,2) > 11))
   fly_combined(find(fly_combined(:,2) > 11),2) = 11; 
end


% START BINNING!!! 
% convert everything to 1mm x 1mm "position coordinate" bins
[xnum, xbins] = histc(fly_combined(:,1), ...
    linspace(0,inner_diameter, inner_diameter * 10));
[ynum, ybins] = histc(fly_combined(:,2), ...
    linspace(0,total_height, total_height*10 ));
% bin on a per-"position coordinate" basis
bin_matrix = full(sparse(ybins, xbins, 1));

% now convert to log(probability)
%total_binCount = sum(sum(bin_matrix));
probMatrix = log(bin_matrix/numRows);

%% plot heatmap

figure('Name', 'Position heatmap');

heatXLab = 0.1:0.1:inner_diameter;
heatYLab = 0.1:0.1:total_height;

posMap = heatmap(probMatrix, heatXLab, heatYLab, [], ...
    'Colormap', 'hot', 'Colorbar', true);
axis('equal', 'manual')
xlabel('X-coordinate (cm)', 'fontsize', 11)
ylabel('Y-coordinate (cm)', 'fontsize', 11)

return;