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

% plot files individually
figure('Name', 'Stacked position traces');
% read files and plot trace
colormap = jet(length(inputFiles));

hold on;
for fileNum = 1:length(inputFiles)
    replicate = csvread(char(inputFiles(fileNum))); 
    % remove NaNs
    for col = 2:size(replicate,2)
        column = replicate(:, col);
        column = column(~isnan(column));
        replicate(1:length(column),col) = column;
    end    
    replicate = replicate(1:length(column), :);
    % preliminary filtering
    replicate = distFilter(replicate, 2);
    % normalize to first point
    for col = 2:size(replicate,2)
        replicate(:, col) = replicate(:, col) - replicate(1, col);
    end
    
    plot(replicate(:,2), replicate(:,3), ...
        'linew', 1.5, 'LineSmoothing', 'on', ...
        'color', colormap(fileNum, :));
end
hold off;

axis([-bounds bounds -bounds bounds], 'equal', 'manual');
plotLabel = cleanLabels(inputFiles);
legend(plotLabel, 'location', 'eastoutside');
