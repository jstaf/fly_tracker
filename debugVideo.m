function debugVideo(binaryLabelArray, outputVideoName, framerate)

% This function creates a video from an array of regions created by the
% bwlabel command. The first two dimensions are the image itself, and the
% third is the series of images (if that makes sense).

% generate colors
maximum = max(binaryLabelArray(:));
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
% randomize colormap for more variety
randomIdx = randperm(maximum);
colorMap = colorMap(randomIdx, :);

%% write video to disk

waitDialog = waitbar(0, 'Creating video...');
blSize = size(binaryLabelArray);
movieFrame = zeros(blSize(1), blSize(2), 3, 'uint8');

writer = VideoWriter(outputVideoName);
writer.FrameRate = framerate;
open(writer);
for nofr = 1:blSize(3)
    waitbar(nofr/blSize(3), waitDialog, ...
        strcat({'Writing frame'},{' '}, num2str(nofr), {' '}, {'of'}, {' '}, num2str(blSize(3))));
    for channel = 1:3
        movieFrame(:,:,channel) = binaryLabelArray(:,:,nofr);
        for color = 1:maximum
            % color pixels according to region number
            tmp = movieFrame(:,:,channel);
            tmp(tmp == color) = colorMap(color,channel);    
            movieFrame(:,:,channel) = tmp;
        end
    end
    % add text labels
    movieProps = regionprops(binaryLabelArray(:,:,nofr),'Centroid');
    for labelNumber = 1:((length([movieProps.Centroid]))/2)
        if isfinite(movieProps(labelNumber).Centroid)
            movieFrame = insertText(movieFrame, movieProps(labelNumber).Centroid, labelNumber, 'BoxColor', [255,255,255]);
        end
    end
    writeVideo(writer, im2frame(movieFrame));
end
close(writer);
close(waitDialog);

return;