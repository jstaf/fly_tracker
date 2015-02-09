function [array] = distFilter(array, teleDistThreshold)

numAvg = 5;

% Teleport filter. Removes spurious points where fly position teleports all
% over the vial due to a false track.
teleFiltNum = 0;
for dim = 2:2:size(array,2)-1
    for numPoint = (numAvg+1):(size(array,1)-numAvg)
        point = array(numPoint, dim:(dim+1));
        if isnan(point) == true
            continue
        else
            % Compute mean positions for last and next numAvg frames.
            lastSet = array((numPoint - numAvg):(numPoint-1), dim:(dim+1));
            lastSet = lastSet(~isnan(lastSet));
            lastMean = mean(reshape(lastSet, ...
                [length(lastSet)/2, 2]), 1);
            nextSet = array((numPoint - numAvg):(numPoint-1), dim:(dim+1));
            nextSet = nextSet(~isnan(nextSet));
            nextMean = mean(reshape(nextSet, ...
                [length(nextSet)/2, 2]), 1);
            
            % If the fly distance between current and next/last mean
            % positions suddenly moves more than the threshold, remove
            % that point.
            if ((pdist2(point,lastMean) > teleDistThreshold) || ...
                    (pdist2(point,nextMean) > teleDistThreshold))
                array(numPoint, dim:(dim+1)) = NaN;
                teleFiltNum = teleFiltNum + 1;
            end
        end
    end
end
disp(strcat(num2str(teleFiltNum), {' '}, 'points removed by the telportation filter.'));

return;