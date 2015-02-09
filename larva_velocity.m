% velocity stats

%% initialize

file_list = {'larvaTrack1.csv'};

% How long is the assay (in seconds)? If one of the csv files is shorter
% than this, defaults to the shorter time.
total_time = 120;

% What was your framerate? The Pentax cameras we use can capture at either 15 or 30 fps.
framerate = 30;

%% read files and assemble into array

if (isa(file_list,'char'))
    file_list = {file_list};
end
num_files = size(file_list);
num_files = num_files(2);
disp(strcat(num2str(num_files), ' files selected for analysis.'));
disp('Loading...');

% Iterates through every row of each file and adds it to "rep_combined"
% array as long as there is video remaining. If video runs out of frames
% for any replicate, chops length of all videos to minimum video length.
total_frames = total_time * framerate;
rep_combined = zeros(total_frames, 3, num_files); % FIX THIS LINE ... specifically the 3
for index = 1:num_files
    disp(file_list(index));
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

% horzcat down the rep_combined dimensions

%% calculate velocities

velocity = zeros(size(rep_combined,1),1);
for row = 2:size(rep_combined,1)
    velocity(row,:) = 10 * pdist2([rep_combined(row,2), rep_combined(row,3)], ... % the '10*' converts to mm/s
        [rep_combined(row-1,2), rep_combined(row-1,3)]);
end
% filter out absurd velocities
velocity(velocity > 0.5) = NaN;
% TODO interpolate NaNs

seconds = floor(size(velocity,1)/framerate);
meanVel = zeros(seconds,1);
for second = 1:seconds
    meanVel(second,:) = mean(velocity((second*framerate)-29:second*framerate));
end

%% plot data

figure('Name','Larva velocity');
plot(meanVel);
axis([0 total_frames/framerate 0 0.5])
xlabel('Time(s)', 'fontsize', 11);
ylabel('Velocity (mm/s)', 'fontsize', 11);