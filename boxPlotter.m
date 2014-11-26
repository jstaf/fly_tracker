%function boxPlotter(inputFiles)

% Test function call. 
% barPlotter('test.csv')

% Load interfly distance files.
inputFiles = {'test.csv', 'test_short.csv', 'test_long.csv'};

distThresh = 6;

num_files = length(inputFiles);
disp(strcat(num2str(num_files), ' files selected for analysis.'));

%% read the files, calculate time interfly disance is within a certain 'distThresh' of each other.

disp('Loading files...');
%read file and calculate stats for each...
plotData = zeros(100,num_files);
plotData(:,:) = NaN;
for fileNum = 1:num_files
    rep_new = csvread(char(inputFiles(fileNum)));
    within_thresh = zeros(size(rep_new));
    for row = 1:size(rep_new,1)
        for col = 1:size(rep_new,2)
            % are the flies within a certain distance threshold of each other?
            if (rep_new(row,col) < distThresh)
                within_thresh(row,col) = 1;
            end
        end
    end
    % Average fractional time is just the total number of points below the
    % threshold divided by the total number of points for each replicate.
    repData = (sum(within_thresh, 1)/size(rep_new,1))';
    plotData((1:length(repData)),fileNum) = repData;
end

%% now make a box plot

boxplot(plotData, ...
    'labels', inputFiles);
ylim([0 max(max(plotData)) + 0.1]);
ylabel(strcat('Average fractional time '), 'fontsize', 11);
