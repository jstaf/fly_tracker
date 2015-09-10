fly_tracker
===========
A set of MATLAB algorithms designed to track Drosophila and their larvae without requiring any kind of special hardware (even videos from cellphone cameras will work). The fly tracking algorithms are extremely resilient and are even able to function if the animal doesn't move through the entire video or gets obscured by glare (this would normally kill another tracking algorithm). Data QC and cleaing is performed automatically.

Descriptions of what each script does:  
+ **flytrack_video.m** - Tracks flies from a video. Optimized for fast moving objects like adult flies. Loosely based on FTrack.
+ **larva_tracker.m** - An alternate video tracking algorithm optimized for slow objects/stuff that barely even moves, like fly larvae.
+ **calc_velocity.m** - Calculate velocities from a set of position .csvs
+ **stackTrace.m** - Creates stacked position traces from a set of position .csvs.
+ **position_heatmap.m** - Make a heatmap of fly positions with the log(probability) of an animal being in a given location.
+ **boxPlotter.m** - Make a nice box plot of your data with standard error of the mean and individual replicates plotted on top.
+ The other files in this repository are utility functions and debugging tools that come in useful from time to time.

##Examples

Example position trace for an adult fly (the fly starts at the dark blue point and moves to the bright yellow one over the course of the video)

![Imgur](http://i.imgur.com/UO5OyrO.png)

Stacked position traces for multiple videos (without offset for initial positions)

![Imgur](http://i.imgur.com/7kLMQEJ.png)

Heatmap of fly positions across multiple videos (0.2 cm bin size)

![Imgur](http://i.imgur.com/aModsIt.png)

Fly velocities across multiple videos

![Imgur](http://i.imgur.com/8Cogmko.png)
