%% initialize
% Create a set of stacked position traces. 

% if true, will not offset positions based on a fly's starting point
preserveOrigin = false;

% size of the arena
bounds = 8;

%% open files
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
    replicate = distFilter(replicate, 1);
    
    if ~preserveOrigin
        % normalize to first point
        for col = 2:size(replicate,2)
            replicate(:, col) = replicate(:, col) - replicate(1, col);
        end
    end
    
    plot(replicate(:,2), replicate(:,3), ...
        'linew', 1.5, 'LineSmoothing', 'on', ...
        'color', colormap(fileNum, :));
end
hold off;

axis('equal', 'manual');
set(gca, 'Ydir', 'reverse');
if preserveOrigin
    axis([0, bounds, 0, bounds]);
else
    axis([-bounds, bounds, -bounds, bounds]);
end
plotLabel = cleanLabels(inputFiles);
legend(plotLabel, 'location', 'eastoutside');

