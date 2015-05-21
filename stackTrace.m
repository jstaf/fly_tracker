%% initialize

% This file opens a set of position traces and stacks and plots them on the
% same set of coordinates.

inputFiles = uipickfiles();
if (isempty(inputFiles))
    disp('No files selected.');
    break;
end

% catch the 1 file error
if (isa(inputFiles,'char'))
    inputFiles = {inputFiles};
end

%% make plots

bounds = 5;

handle = figure;
% read files and plot trace
colormap = jet(length(inputFiles));

plotLabel = cleanLabels(inputFiles);

hold on;
for fileNum = 1:length(inputFiles)
    replicate = csvread(char(inputFiles(fileNum))); 
    % normalize everything in relation to the first datapoint
    for col = 2:size(replicate,2)
        column = replicate(:, col);
        column = column(~isnan(column));
        replicate(1:length(column),col) = column(:) - column(1);
    end
    replicate = replicate(1:length(column), :);
    plot(replicate(:,2), replicate(:,3), ...
        'linew', 2, 'LineSmoothing', 'on', ...
        'color', colormap(fileNum, :));
end
axis([-bounds bounds -bounds bounds]);
legend(plotLabel, 'location', 'East');

hold off;