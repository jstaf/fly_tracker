function showRegions(binaryLabelImg)

% generate colors
maximum = max(binaryLabelImg(:));
colorMap = zeros(maximum, 3);
for i = 1:maximum
    val = double(i)/double(maximum);
    % r channel
    colorMap(i,1) = ceil(255*val);
    % g channel
    if val < 0.5
        colorMap(i,2) = ceil(255*val*2);
    else
        colorMap(i,2) = 255 - ceil(255*(val-0.5)*2);
    end
    % b channel
    colorMap(i,3) = 255 - ceil(255*val);
end

colorFrame = zeros(size(binaryLabelImg,1), size(binaryLabelImg,2), 3, 'uint8');
for channel = 1:3
    colorFrame(:,:,channel) = binaryLabelImg;
    for color = 1:maximum
        % color pixels according to region number
        tmp = colorFrame(:,:,channel);
        tmp(tmp == color) = colorMap(color,channel);
        colorFrame(:,:,channel) = tmp;
    end
end
% add text labels
props = regionprops(binaryLabelImg,'Centroid');
for labelNumber = 1:((length([props.Centroid]))/2)
    colorFrame = insertText(colorFrame, props(labelNumber).Centroid, labelNumber, 'BoxColor', [255,255,255]);
end
figure('Name', 'Converted image');
imshow(colorFrame);

return