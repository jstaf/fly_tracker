%% initialize settings

% This script loads output data from the flytrack_video script, collapses
% data from multiple replicates, and performs a bit of visualization. 

% Jeff Stafford

% Known issues:
% -the heatmap needs to be prettier, much prettier...

% File list to load. Write the names of the files you want to load here in
% a comma delimited list. THEY MUST ALL BE IN THE WORKING DIRECTORY OF THIS SCRIPT OR IT WONT WORK.
file_list = {'171.csv', '172.csv', '173.csv', '174.csv', '175.csv'};

% How long is the assay (in seconds)? If one of the csv files is shorter
% than this, defaults to the shorter time.
total_time = 120;

% What was your framerate? The Pentax cameras we use can capture at either 15 or 30 fps.
framerate = 30;

%input dimensions of assay vial, units in cm
top_half_height = 3;
bottom_half_height = 8;
inner_diameter = 1.5;

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

%% bin positions from array

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
% dumps fly 1 and fly 2 into a common array, comment this part out for only
% bottom fly
fly_combined = vertcat(rep_combined_lg(:,2:3), rep_combined_lg(:,4:5));

% START BINNING!!! 
% convert everything to 1mm x 1mm "position coordinate" bins
[xnum, xbins] = histc(fly_combined(:,1), ...
    linspace(min(fly_combined(:,1)),max(fly_combined(:,1)), 15));
[ynum, ybins] = histc(fly_combined(:,2), ...
    linspace(min(fly_combined(:,2)),max(fly_combined(:,2)), 110));
% bin on a per-"position coordinate" basis
bin_matrix = full(sparse(ybins, xbins, 1));

% old binning code... only difference is the indexing % START BINNING!!!
% % convert everything to 1mm x 1mm "position coordinate" bins
% [xnum, xbins] = histc(rep_combined_lg(:,2), ...
%     linspace(min(rep_combined_lg(:,2)),max(rep_combined_lg(:,2)), 15));
% [ynum, ybins] = histc(rep_combined_lg(:,3), ...
%     linspace(min(rep_combined_lg(:,3)),max(rep_combined_lg(:,3)), 110));
% % bin on a per-"position coordinate" basis
% bin_matrix = full(sparse(ybins, xbins, 1));

%% plot output

bin_matrix_flip = flipud(bin_matrix);
heatmap = HeatMap(log(bin_matrix_flip), ...
    'Colormap', 'jet' ...
    );