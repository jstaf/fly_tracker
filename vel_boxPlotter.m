%% initialize

% When in each video do you want to begin the mean velocity calculations?
% (in seconds)
start_delay = 30;

%% cat together a bunch of velocity files and run stats
    
[video_name, pathname] = uigetfile({'*.csv;*', ...
    'Comma-separated values (*.csv)'}, ...
    'Select a set of flypath files (created by "larva_velocity.m")...', 'MultiSelect','on');
if (pathname ~= 0)
    inputFiles = strcat(pathname,video_name);
else
    break;
end

if (start_delay == 0)
    start_delay = start_delay + 1;
end

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
    avgVel = zeros(size(rep_new,2),1);
    for col = 1:size(rep_new,2)
        velData = rep_new(start_delay:size(rep_new,1),col);
        avgVel(col) = mean(velData(~isnan(velData)));
    end
    plotData((1:length(avgVel)),fileNum) = avgVel;
end

%% lets do some stats

if (num_files == 2)
    disp('Two files detected, performing two-sample t-test.');
    x = plotData(:,1);
    x = x(~isnan(x));
    y = plotData(:,2);
    y = y(~isnan(y));
    [handle, pval, conf_int, stats] = ttest2(x,y);
    if (pval <= 0.05)
        disp(strcat('Null hypothesis rejected, p-value =', {' '}, num2str(pval)));
    else
        disp(strcat('Failed to reject the null hypothesis, p-value =', {' '}, num2str(pval)));
    end
elseif (num_files > 2) 
    disp('More than two groups detected, using one-way ANOVA with post-hoc Tukey HSD');
    [pval, tbl, stats] = anova1(plotData);
    if (pval <= 0.05)
        multcompare(stats);
    end
end

%% now make a box plot

figure('Name', strcat('Velocity'));
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
ylim([0 (max(max(plotData)) + 0.1)]);
ylabel(strcat('Average velocity (mm/s) '), 'fontsize', 11);
