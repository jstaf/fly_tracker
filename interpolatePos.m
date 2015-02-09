function [array] = interpolatePos(array, interDistThreshold)

% The script will linearly interpolate the flies' position between points
% as long as the fly doesn't move that much (interDistThreshold) between
% frames.

%iterate through datapoints for all four position columns
interpolationNumber = 0;
for dim = 2:2:size(array,2)-1
    numPoint = 1;
    while numPoint < size(array,1)
        point = array(numPoint,dim);
        % If it encounters an NaN, find the last point that was not an
        % NaN and the next point that is not an NaN.
        if ((isnan(point) == true) && (numPoint ~= 1))
            lastIdx = numPoint - 1;
            lastPoint = array(lastIdx,dim:(dim+1));
            nextIdx = find(~isnan(array(numPoint:size(array,1),dim)) ,1,'first') + numPoint - 1;
            if isempty(nextIdx)
                break
            end
            nextPoint = array(nextIdx,dim:(dim+1));
            diff = nextIdx - numPoint;
            
            %check to make sure that the values aren't too far apart to
            %interpolate, then replace bad values!
            interPDist = pdist2(lastPoint,nextPoint);
            if interPDist <= interDistThreshold
                for badFrameNum =  1:diff
                    array((lastIdx + badFrameNum),dim:(dim+1)) = ...
                        lastPoint + ( (nextPoint - lastPoint) * badFrameNum/(diff+1));
                end
                interpolationNumber = interpolationNumber + diff;
            end
            
            % Keep track of how many frames we've interpolated and skip
            % to next non-NaN value.
            numPoint = nextIdx;
            
        elseif ((isnan(point) == true) && (numPoint == 1))
            numPoint = find(~isnan(array(:,dim)), 1,'first');
        else
            numPoint = numPoint + 1;
        end
    end
end
disp(strcat(num2str(interpolationNumber), {' '}, 'points recovered through interpolation.'))

return;