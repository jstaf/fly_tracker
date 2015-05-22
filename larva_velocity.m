% velocity stats

%% initialize

% How long is the assay (in seconds)? If one of the csv files is shorter
% than this, defaults to the shorter time.
total_time = 90;

% Bin size for velocity calculations (in seconds). Velocity is calculated
% once per "bin size" by comparing positions at the start and end. Cannot
% be lower than the rate of data being analyzed (generally 0.5-1s).
binSize = 1;

%% get file list

[file_name, pathname] = uigetfile({'*.csv;*', ...
    'Comma-separated values (*.csv)'}, ...
    'Select a set of flypath files (created by "larva_tracker.m")...', 'MultiSelect','on');
if (pathname ~= 0)
    file_list = strcat(pathname,file_name);
else
    break;
end

if (isa(file_list,'char'))
    file_list = {file_list};
end
num_files = size(file_list,2);
disp(strcat(num2str(num_files), ' files selected for analysis.'));

%% calculate mean velocity per second for each replicate

% recalculate total time to total # of bins
total_time = floor(total_time / binSize);
seconds = floor(total_time);
meanVel = zeros(seconds, num_files);
meanVel(:) = NaN;
larvaNum = 1;
for index = 1:num_files
    %load file
    disp(cleanLabels(file_list(index)));
    replicate = csvread(char(file_list(index)));
    num_rows = size(replicate,1);
    
    % extend meanVel array if we need to
    colsToAdd = size(replicate,2) - 3;
    if (colsToAdd > 0)
        newSpace = zeros(seconds, colsToAdd);
        newSpace(:) = NaN;
        meanVel = horzcat(meanVel, newSpace); %#ok<AGROW>
    end
    
    % calc velocities
    dataRate = round(1 / replicate(2, 1)) * binSize;
    velocity = zeros(seconds, 1);
    velocity(:) = NaN;
    for animal = 1:2:(size(replicate, 2) - 1)
        % calculate velocity/s for each animal
        for row = 1:dataRate:(size(replicate, 1) - dataRate)
            % the '10 * ' converts to mm/s (coordinates are in cm)
            velocity(floor(row/dataRate)+1) = 10 * pdist2( ...
                [replicate(row,animal+1), replicate(row,animal+2)], ...
                [replicate(row+dataRate,animal+1), replicate(row+dataRate,animal+2)]);
        end
        % convert from mm/bin to mm/s
        velocity = velocity / binSize;
        
        
        if (length(velocity) > total_time)
            meanVel(:,larvaNum) = velocity(1:total_time);
        else
            meanVel(:,larvaNum) = velocity;
        end
        larvaNum = larvaNum + 1;
    end
end

% remove any absurd velocities that aren't actually possible (in this case over 1 cm/s)
meanVel(meanVel > 10) = NaN;

% find last datapoint and cut array down to size
lastIdx = zeros(size(meanVel,2),1);
for col = 1:size(meanVel,2)
    lastNonNaN = find(~isnan(meanVel(:,col)),1,'last');
    if (~isempty(lastNonNaN))
        lastIdx(col) = find(~isnan(meanVel(:,col)),1,'last');
    else
        % change entire velocity to zero, the larva likely didn't move
        meanVel(:,col) = 0;
        lastIdx(col) = NaN;
    end
end
meanVel = meanVel(1:max(lastIdx),:);

%% plot data

figure('Name','Larva velocity');
colormap = jet(size(meanVel, 2));
hold on;
for col = 1:size(meanVel, 2)
    plot((1:seconds) * binSize, meanVel(:, col), ...
        'linew', 1.5, 'LineSmoothing', 'on', 'color', colormap(col, :));
end
hold off;
axis([0 ((size(meanVel,1) + 1) * binSize) 0 max(meanVel(:)*1.5)])
xlabel('Time (s)', 'fontsize', 11);
ylabel('Average velocity (mm/s)', 'fontsize', 11);

legend(cleanLabels(file_list), 'location', 'NorthWest');

%% write data to disk

[output_name,path] = uiputfile('.csv');
if output_name ~= 0  % in case someone closes the file saving dialog
    csvwrite(strcat(path,output_name), meanVel);
else
    disp('File saving cancelled.')
end