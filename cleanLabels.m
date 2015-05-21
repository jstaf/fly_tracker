function [plotLabel] = cleanLabels(plotLabel)

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

return;