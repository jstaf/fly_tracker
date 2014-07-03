%% initialize settings

% This script loads output data from the flytrack_video script, collapses
% data from multiple replicates, and performs stats. 

% Jeff Stafford

% File list to load. Write the names of the files you want to load here.
% THEY MUST BE IN THE WORKING DIRECTORY OF THIS SCRIPT OR IT WONT WORK.
file_list = {'tracker_out.csv', 'tracker_out2.csv' };

% How long is the assay (in seconds)? If one of the csv files is shorter
% than this, defaults to the shorter time.
total_time = 120;

% What was your framerate? The Pentax cameras we use can capture at either 15 or 30 fps.
framerate = 15;

%input dimensions of assay vial, units in cm
top_half_height = 3;
bottom_half_height = 8;
inner_diameter = 1.5;

%% read files and assemble into array

num_files = size(file_list);
num_files = num_files(2);
disp({num_files 'files selected for analysis.'});

% Iterates through every row of each file and adds it to "rep_combined"
% array as long as there is video remaining. If video runs out of frames
% for any replicate, chops length of all videos to minimum video length.
total_frames = total_time * framerate;
rep_combined = zeros(total_frames, 3, num_files);
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


