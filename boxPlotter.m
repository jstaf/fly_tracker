%% initialize

% When in each video do you want to begin the mean velocity calculations?
% (in seconds)
start_delay = 0;

%% select files
    
[inputFiles] = uipickfiles();

if (start_delay == 0)
    start_delay = start_delay + 1;
end

%% read each file and calculate mean velocity

num_files = length(inputFiles);
plotData = zeros(100, num_files);
plotData(:) = NaN;
for fileNum = 1:num_files
    rep_new = csvread(char(inputFiles(fileNum)));
    
    % adjust start delay based on first time measurement in file
    startDelFile = ceil(start_delay / rep_new(2, 1)) + 1;
    
    % calc avg velocity
    avgVel = zeros(size(rep_new, 2) - 1, 1);
    for col = 2:size(rep_new, 2)
        velData = rep_new(startDelFile:size(rep_new, 1), col);
        avgVel(col - 1) = mean(velData(~isnan(velData)));
    end
    avgVel = avgVel(~isnan(avgVel));
    plotData((1:length(avgVel)), fileNum) = avgVel;
end

%% lets do some stats

if (num_files == 2)
    disp('Two files detected, performing two-sample t-test.');
    x = plotData(:,1);
    x = x(~isnan(x));
    y = plotData(:,2);
    y = y(~isnan(y));
    [decision, pval, conf_int, stats] = ttest2(x,y);
    if (pval <= 0.05)
        disp(['Null hypothesis rejected, p-value = ',num2str(pval)]);
    else
        disp(['Failed to reject the null hypothesis, p-value = ' num2str(pval)]);
    end
elseif (num_files > 2) 
    disp('More than two groups detected, using one-way ANOVA with post-hoc Tukey HSD');
    [pval, tbl, stats] = anova1(plotData);
    if (pval <= 0.05)
        multcompare(stats);
    end
end

%% now make a box plot

% controls width of bars and jittering
wide = 0.3;

figure('Name', strcat('Velocity'));
hold on;
% plot datainputFiles
for col = 1:size(plotData, 2)
    % generate plotMean and sem for column in question
    dat = plotData(:, col);
    dat = dat(~isnan(dat));
    plotMean = mean(dat);
    sem = std(dat)/sqrt(length(dat));
    
    % draw sem patch (Position = [x vert], [y vert], color)
    % starts in lower left corner and goes clockwise
    patch([col - wide, col - wide, col + wide, col + wide], ...
        [plotMean - sem, plotMean + sem, plotMean + sem, plotMean - sem], ...
        'r', 'FaceAlpha', 0.2, 'LineStyle', 'none');
    
    % draw mean line
    plot([col - wide, col + wide], [plotMean, plotMean], ...
        'linew', 1.5, ...
        'color', [1, 0, 0]);
    
    % draw individual points
    points = scatter(repmat(col, size(plotData, 1), 1), plotData(:, col), ...
        45, [0.5, 0.5, 0.5], 'filled', ... % size, color, fill
        'Jitter', 'on', 'JitterAmount', wide - 0.1);
    % uistack(points, 'top');
end
hold off;

% set axis and labels to use manual labels from file names
plotLabel = cleanLabels(inputFiles);
set(gca, ...
    'XLim', [0, size(plotData, 2) + 1], ...
    'XTick', 1:size(plotData, 2), ...
    'XTickLabel', plotLabel);
% rotateXLabels(gca(), 45) % looks awful
ylim([0 (max(max(plotData)) + 0.1)]);
ylabel(strcat('Average velocity (mm/s) '), 'fontsize', 11);
