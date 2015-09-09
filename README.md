fly_tracker
===========

A short little MATLAB script that tracks flies.

This program analyzes fruit fly (or other small insect) trajectories in a cyndrilical arena. Outputs the coordinates of each fly, distance between two flies, and also a heatmap of the relative probability of a fly being in any given spot. Most settings can be specified by the user using the GUI. 

Hit "Analyze Video" to track the flies in a video, examine the output for multiple replicates of a given genotype with the "Statistics" button (loads .csv files from video analysis), and compare the amount of time flies spend below a certain distance from each other with the "Compare" button (loads .csv files created by the statistics function). 

Note:
When running the "Analyze Video" function, it will prompt you for 'rotation correction' (click-and-drag to draw a line parallel to the arena's height, then double-click) and a region-of-interest (click-and-drag to define the inside of the arena, double-click to proceed). When performing 'rotation correction,' the first point you draw should correspond to the top of the arena.

Contact me at jeff.stafford@live.com if you have any questions about its use or are looking to use it for a publication. Also end me an email if you run into any glaring issues or bugs.

Unless stated otherwise, I reserve all rights to this software, including, but not limited to commercial use or inclusion in a scientific publication.
