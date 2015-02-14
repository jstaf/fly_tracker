% velocity stats

%% initialize

[video_name, pathname] = uigetfile({'*.csv;*', ...
    'Comma-separated values (*.csv)'}, ...
    'Select a set of flypath files (created by "larva_tracker.m")...', 'MultiSelect','on');
if (pathname ~= 0)
    file_list = strcat(pathname,video_name);
else
    break;
end

%file_list = {'larvaTrack1.csv', 'larvaTrack1-1.csv'};

% How long is the assay (in seconds)? If one of the csv files is shorter
% than this, defaults to the shorter time.
total_time = 240;

% What was your framerate? The Pentax cameras we use can capture at either 15 or 30 fps.
framerate = 30;

%% read files and assemble into array

if (isa(file_list,'char'))
    file_list = {file_list};
end
num_files = size(file_list,2);
disp(strcat(num2str(num_files), ' files selected for analysis.'));

% calculate mean velocity per second for each replicate
seconds = floor(total_time);
velocity = zeros(seconds*framerate,1);
meanVel = zeros(seconds,num_files);
meanVel(:) = NaN;
larvaNum = 1;
for index = 1:num_files
    %load file
    disp(file_list(index));
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
    velocity(:) = NaN; % needs to be reset to original state
    for animal = 1:2:(size(replicate,2)-1)
        % calculate velocity for each animal
        for row = 2:num_rows
            % the '10 * ' converts to mm/s
            velocity(row,:) = 10 * pdist2( ...
                [replicate(row,animal+1), replicate(row,animal+2)], ...
                [replicate(row-1,animal+1), replicate(row-1,animal+2)]);
        end
        
        % filter out absurd velocities
        velocity(velocity > 0.5) = NaN;
        
        %compute average velocity
        for second = 1:seconds
            velData = velocity((second*framerate)-29:second*framerate);
            meanVel(second,larvaNum) = mean(velData);
            %meanVel(second,larvaNum) = mean(velData(~isnan(velData)));
        end
        larvaNum = larvaNum + 1;
    end
end

% find last datapoint and cut array down to size
lastIdx = zeros(size(meanVel,2),1);
for col = 1:size(meanVel,2)
    lastIdx(col) = find(~isnan(meanVel(:,col)),1,'last');
end
meanVel = meanVel(1:max(lastIdx),:);

%% plot data

figure('Name','Larva velocity');
plot(meanVel);
axis([0 size(meanVel,1)+5 0 max(meanVel(:)*1.5)])
xlabel('Time (s)', 'fontsize', 11);
ylabel('Velocity (mm/s)', 'fontsize', 11);

legend(video_name, 'location', 'NorthWest');

%% write data to disk

[output_name,path] = uiputfile('.csv');
if output_name ~= 0  % in case someone closes the file saving dialog
    csvwrite(strcat(path,output_name), meanVel);
else
    disp('File saving cancelled.')
end