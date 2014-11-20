%function boxPlotter(inputFiles, total_time)

% Test function call. 
% barPlotter('test.csv', 120)

% Load interfly distance files.
inputFiles = {'test.csv'};
% Specify how long the amount of time you want to analyze in seconds.
total_time = 120;

% What was your framerate? The Pentax cameras we use can capture at either 15 or 30 fps.
framerate = 30;

num_files = length(inputFiles);
disp(strcat(num2str(num_files), ' files selected for analysis.'));

%% read the files

disp('Loading files...');
total_frames = total_time * framerate;
open_init = csvread(char(inputFiles(1)) );

rep_combined = zeros(size(open_init,1));
if length(rep_combined) > total_frames
    rep_combined = rep_combined(1:total_frames,:,:);
end

%read file and calculate stats for each, dont do it this way...

% now read additional files, cut them down to size, and add to rep_combined
if num_files > 1
    for fileNum = 1:num_files
        rep_new = csvread(char(inputFiles(fileNum)));
        if size(rep_new,1) > size(rep_combined,1)
            rep_new = rep_new(1:size(rep_combined,1));
        elseif (size(rep_new,1) < size(rep_combined,1))
            rep_combined = rep
        end
        rep_combined = [rep_combined,rep_new];
    end
end

%% okay calculate amt of time spent < 5mm apart

% are the flies within a certain distance threshold of each other?
distThresh = 6;
within_thresh = zeros(size(rep_combined));
for row = 1:size(rep_combined,1)
    for col = 1:size(rep_combined,2)
       if (rep_combined(row, col) < distThresh)
           within_thresh(row, col) = 1;
       end
    end
end
plotData = (sum(within_thresh, 1)/size(rep_combined,1))';



%% now make a box plot

boxplot(plotData, ...
    'labels', inputFiles);
ylim([0 max(plotData) + 0.1]);
ylabel(strcat('Average fractional time '), 'fontsize', 11);


