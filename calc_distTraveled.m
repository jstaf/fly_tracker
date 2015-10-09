% CALCULATE DISTANCE TRAVELED DURING AN ASSAY
% Jeff Stafford

%% initialize

% How long is the assay (in seconds)? If one of the csv files is shorter
% than this, defaults to the shorter time.
total_time = 90;

% Bin size for distance calculations (in seconds). Distance is calculated
% once per "bin size" by comparing positions at the start and end. Cannot
% be lower than the rate of data being analyzed. 
binSize = 0.033333;

%% get file list

[file_name, pathname] = uigetfile({'*.csv;*', ...
    'Comma-separated values (*.csv)'}, ...
    'Select a set of flypath files (created by "larva_tracker.m")...', 'MultiSelect','on');
file_list = strcat(pathname, file_name);

if (isa(file_list,'char'))
    file_list = {file_list};
end
num_files = size(file_list,2);
disp(strcat(num2str(num_files), ' files selected for analysis.'));

% We have to quickly open the files and see how long they are
% (in seconds) to make sure we quantify them all an equal length of time
fileSize = zeros(num_files, 1);
for index = 1:num_files
    replicate = csvread(char(file_list(index)));
    fileSize(index) = replicate(end, 1);
end
if min(fileSize) < total_time
    warning('One or more files is shorter than <total_time>, using minimum file duration as <total_time> instead.')
    total_time = min(fileSize);
end

% recalculate total time to total # of bins
total_time = floor(total_time / binSize);

%% calculate distance traveled for each replicate

seconds = 1;
dists = zeros(seconds, num_files);
dists(:) = NaN;
larvaNum = 1;
for index = 1:num_files
    %load file
    disp(cleanLabels(file_list(index)));
    replicate = csvread(char(file_list(index)));
    num_rows = size(replicate,1);
    
    % extend dists array if we need to
    colsToAdd = size(replicate,2) - 3;
    if (colsToAdd > 0)
        newSpace = zeros(seconds, colsToAdd);
        newSpace(:) = NaN;
        dists = [dists, newSpace]; %#ok<AGROW>
    end
    
    %%% FUCK THIS LINE
    dataRate = round(1 / replicate(2, 1)) * binSize;
    if (dataRate < 1)
        mexception = MException('larva_velocity:BadParam', ... 
            'Error: binSize is smaller than minimum data rate.');
        throw(mexception);
    end
    
    distance = 0;
    for animal = 1:2:(size(replicate, 2) - 1)
        % calculate distance traveled for each animal
        lastBin = 1;
        for row = (dataRate+1):dataRate:size(replicate, 1)
            % the '10 * ' converts to mm/s (coordinates are in cm)
            if ~isnan(replicate(row,animal+1)) && ...
                    ~isnan(replicate(row - (dataRate * lastBin),animal+1))
                
                thisDistance = 10 * pdist2([replicate(row,animal+1), ... 
                    replicate(row,animal+2)], ...
                    [replicate(row - (dataRate * lastBin),animal+1), ...
                    replicate(row - (dataRate * lastBin),animal+2)]);
                % is thisDistance reasonable? (was there a massive frame
                % jump due to a bad track)?
                if thisDistance < 20
                    distance = distance + thisDistance;               
                    lastBin = 1;
                else
                    lastBin = lastBin + 1;
                end
            else
                % skip NaNs, calculate distance between next bin and last bin
                % instead.
                lastBin = lastBin + 1;
            end
        end
        % add to array, move to next animal
        dists(larvaNum) = distance;
        larvaNum = larvaNum + 1;
    end
end

% create a first column of timepoint labels, that indicates the total time
% used
plotData = [total_time * binSize, dists];

%% plot data

figure('Name','Larva velocity');
colormap = jet(size(dists, 2));
hold on;
for col = 2:size(plotData, 2)
    plot(plotData(:, 1), plotData(:, col), ...
        'linew', 1.5, 'LineSmoothing', 'on', 'color', colormap(col - 1, :));
end
hold off;
axis([0 (plotData(end, 1) + binSize) 0 (max(dists(:)) * 1.5)])
xlabel('Time (s)', 'fontsize', 11);
ylabel('Average velocity (mm/s)', 'fontsize', 11);

legend(cleanLabels(file_list), 'location', 'NorthWest');

%% write data to disk

[output_name,path] = uiputfile('.csv');
if output_name ~= 0  % in case someone closes the file saving dialog
    csvwrite(strcat(path,output_name), plotData);
else
    disp('File saving cancelled.')
end