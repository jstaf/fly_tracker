function debugVideo(binaryLabel, outputVideoName, framerate)

% This function creates a video from an array of regions created by the
% bwlabel command. The first two dimensions are the image itself, and the
% third is the series of images (if that makes sense).

% generate colors
maximum = max(binaryLabel(:));
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

% add color data to show labeling
waitDialog = waitbar(0, 'Creating video...');
blSize = size(binaryLabel);
movieFrames = zeros(blSize(1), blSize(2), 3, blSize(3), 'uint8');
for i = 1:3
    movieFrames(:,:,i,:) = binaryLabel(:,:,:);    
end
for nofr = 1:blSize(3)
    waitbar(nofr/nfrm_movie, waitDialog, ...
        strcat({'Creating frame'},{' '}, num2str(nofr), {' '}, {'of'}, {' '}, num2str(nfrm_movie)));
    for channel = 1:3
        for color = 1:maximum
            % color pixels according to region number
            tmp = movieFrames(:,:,channel,nofr);
            tmp(tmp == color) = colorMap(color,channel);    
            movieFrames(:,:,channel,nofr) = tmp;
        end
    end
    % add text labels
    movieProps = regionprops(binaryLabel(:,:,nofr),'Centroid');
    for labelNumber = 1:((length([movieProps.Centroid]))/2)
        movieFrames(:,:,:,nofr) = insertText(movieFrames(:,:,:,nofr), movieProps(labelNumber).Centroid, labelNumber, 'BoxColor', [255,255,255]);
    end
end

% finally write the frames to disk
writer = VideoWriter(outputVideoName);
writer.FrameRate = framerate;
open(writer);
for nofr = 1:nfrm_movie
    waitbar(nofr/nfrm_movie, waitDialog, ...
        strcat({'Writing frame'},{' '}, num2str(nofr), {' '}, {'of'}, {' '}, num2str(nfrm_movie)));
    writeVideo(writer, im2frame(movieFrames(:,:,:,nofr)));
    
end
close(writer);
close(waitDialog);

return;