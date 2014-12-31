function flytracker_main()

wide = 600;
high = 300;

screen = get(0, 'Screensize');
f = figure('Visible','off','Position',[(screen(4)-wide)/2,(screen(3)-high)/2,wide,high]);

title = uicontrol('Style', 'text', 'String', 'Fly Tracker v0.1', ...
    'Position', [25, 260, 200, 25], ...
    'FontSize', 14, 'FontWeight', 'bold');

auth = uicontrol('Style', 'text', 'String', 'Jeff Stafford (stafford@zoology.ubc.ca)', ...
    'Position', [225, 260, 300, 25], 'FontSize', 12);

% log = uicontrol('Style', 'text', 'String', 'Select the files you wish to analyze...', ...
%     'Position', [150, 20, 400, 225], ...
%     'HorizontalAlignment', 'left', 'BackgroundColor', 'white');

fileLoad = uicontrol('Style','pushbutton','String','Analyze videos...',...
    'Position',[25,220,100,25],...
    'Callback',{@fileLoadCallback});

stats = uicontrol('Style','pushbutton','String','Statistics',...
    'Position',[25,190,100,25],...
    'Callback',{@analyze_button});

analyze = uicontrol('Style','pushbutton','String','Compare',...
    'Position',[25,160,100,25],...
    'Callback',{@analyze_button});

settings = uipanel('Title', 'Settings', ...
    'TitlePosition', 'lefttop', ...
    'BorderType', 'etchedin', ...
    'BorderWidth', 1, ...
    'Position', [20, 20, 200, 225]);

threshset = uicontrol('Parent', settings, 'Style', 'edit', 'BackgroundColor', 'white', ...
    'Position', [0, 0, 40, 15], ...
    'Callback', {@setThreshold});

    function [per_pixel_threshold] = setThreshold(hObject, source, eventData)
         per_pixel_threshold = str2double(get(hObject, 'String'));
        if isnan(per_pixel_threshold)
            set(hObject, 'String', 0);
            errordlg('Input must be a number','Error');
        end
        handles.threshold = per_pixel_threshold;
        guidata(hObject,handles)
    end
        

set(f,'Name','Fly Tracker');
movegui(f,'center');
set(f,'Visible','on');

    function [video_name, pathname, numVideos] = fileLoadCallback(source, eventData)
        %get a list of files to open
        [video_name, pathname] = uigetfile({'*.avi;*.mj2;*.mpg;*.mp4;*.m4v;*.mov', ...
            'Video Files (*.avi;*.mj2;*.mpg;*.mp4;*.m4v;*.mov)'}, ...
            'Select a video to analyze...', 'MultiSelect','on');
        numVideos = length(video_name);
        video_name = {video_name};
        [corrected_array] = flytrack_video_fn(video_name(1));
    end

end