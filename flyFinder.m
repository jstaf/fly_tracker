function [fr_position] = flyFinder(ROI_image, search_size, threshold, flip)

%flyFinder
%
% Usage:
%   [fr_position] = flyFinder(ROI_image, search_size, threshold)
% 
% This function finds a fly (region of darkness) in an image matrix (ROI_image).
% Locates the darkest pixel in the image, retrieves a "search area"
% (2 x search size), and finds the center of pixel intensity for that area
% after inverting image intensities.

% Locate darkest pixel.
if flip
    val = min(ROI_image(:));
else
    val = max(ROI_image(:));
end
[ypos, xpos] = find(ROI_image == val);
xpos = mean(xpos);
ypos = mean(ypos);

leftEdge = int16(round(xpos) - search_size);
rightEdge = int16(round(xpos) + search_size);
topEdge = int16(round(ypos) - search_size);
bottomEdge = int16(round(ypos) + search_size);

% Make sure edges do not fall outside ROI_image bounds.
if leftEdge < 1
    leftEdge = 1;
end
if rightEdge > length(ROI_image(1,:));
    rightEdge = length(ROI_image(1,:));
end
if topEdge < 1
    topEdge = 1;
end
if bottomEdge > length(ROI_image(:,1));
    bottomEdge = length(ROI_image(:,1));
end

bounds = [leftEdge rightEdge topEdge bottomEdge];
search_area = ROI_image(bounds(3):bounds(4), bounds(1):bounds(2));

% "Flip" image to be white pixels on black.
if flip == true
    search_area = double(255 - search_area);
end
x2 = (1:length(search_area(1,:)))';
y2 = (1:length(search_area(:,1)))';
total = sum(search_area(:));

% Add x and y positions to array if pixel intensity (the fly) is above a
% certain threshold.
if total >= threshold
    x = sum(search_area*x2) / total + leftEdge - 1;
    y = sum(search_area'*y2) / total + topEdge - 1;
    fr_position = [x, y];
else % add NaNs to array if fly is not found.
    fr_position = [NaN, NaN];
end

return;