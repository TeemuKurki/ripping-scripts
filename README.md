# Bash scripts for ripping Blurays and DVDs

## Overview

Scripts for automatically rip DVD and Bluray movies and shows. Scripts for DVD and Bluray are conceptually same, just using different libraries for extracting the data from the disk.

Scripts work in three parts:

- List disk info
- Extract title data
- Transcode and compress data

Data is extracted from disk as is, meaning there is no compressing or transcoding done in data extraction phase. Extracted data is streamed from extraction phase into ffmpeg and comppression and transcoding etc. is done there giving us much more fine-grained control over end result. This was also only reliable way I could find to include subtitles without burning those to video stream directly

### Bluray

**Dependencies**

- libbluray-bin
  - bd_list_titles
  - bd_splice
- libaacs0
- libbluray-bdj
- ffmpeg
- mpv

Utilizes `bd_list_titles` to get list of titles and number of chapters for each title. List is filtered by the length of the title to remove unnecessary videos, such as trailers. For each found title, info is passed to `bd_splice` to combine all chapter together to produce complete movie/episode. Data from `bd_splice` is streamed directly into `ffmpeg` to create compressed .mkv file.

Output file contains the name of the playlist extracted with `bd_list_titles`. This added to help with order of episodes as some Blurays have shuffled the order of episodes.

### DVDs

**Dependencies**

- lsdvd
- mpv
- ffmpeg

Utilizes `lsdvd` to get list of titles and number of chapters for each title. List is filtered by the length of the title to remove unnecessary videos, such as trailers. For each found title, info is passed to `mpv` to produce complete movie/episode. As `mpv` requires output file we create temporary fifo queue for the output and run `ffmpeg` in parallel using temp fifo queue as an input.
