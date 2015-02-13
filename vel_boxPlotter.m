inputFiles = {'track_compile_test1.csv'};

% This is the 'distance threshold' that you are examining (measured in cm). 
% This script calculates what fraction of time the interfly distance was below this threshold.

%% read the files, calculate time interfly disance is within a certain 'distThresh' of each other.

%read file and calculate stats for each...
if (isa(inputFiles,'char'))
    inputFiles = {inputFiles};
end
num_files = length(inputFiles);
plotData = zeros(100,num_files);
plotData(:) = NaN;
for fileNum = 1:num_files
    rep_new = csvread(char(inputFiles(fileNum)));
    
    %calc avg velocity
    avgVel = mean(rep_new,1)';
    plotData((1:length(avgVel)),fileNum) = avgVel;
end

%% now make a box plot

figure('Name', strcat('Average fractional time interfly distance was below the threshold'));
plotLabel = inputFiles;
% remove the path from the labels, if present
for barNum = 1:length(plotLabel)
    barLabel = char(plotLabel(barNum));
    ind = strfind(barLabel, '/');
    if isempty(ind)
        plotLabel(barNum) = {barLabel};
    else
        plotLabel(barNum) = {barLabel(ind(length(ind))+1:length(barLabel))};
    end
end
% remove '.csv' from the labels, if present
for barNum = 1:length(plotLabel)
    barLabel = char(plotLabel(barNum));
    ind = strfind(barLabel, '.csv');
    if isempty(ind)
        plotLabel(barNum) = {barLabel};
    else
        plotLabel(barNum) = {barLabel(1:ind(length(ind))-1)};
    end
end
boxplot(plotData, ...
    'labels', plotLabel);
ylim([0 max(max(plotData)) + 0.1]);
ylabel(strcat('Average velocity (mm/s) '), 'fontsize', 11);
