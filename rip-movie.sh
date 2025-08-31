#!/bin/bash

#Using: mpv, lsdvd, ffmpeg

# Exit on error
set -e

# Default values for PAL DVD
DVD_PATH="/dev/sr0"
MOVIE=""
TITLE_NUM=""
PART=""
QUALITY=25

# --- Parse named arguments ---
for arg in "$@"; do
    case $arg in
        --dvd-path=*)
            DVD_PATH="${arg#*=}"
            ;;
        --movie=*)
            MOVIE="${arg#*=}"
            ;;
        --title-num=*)
            TITLE_NUM="${arg#*=}"
            ;;
        --quality=*)
            QUALITY="${arg#*=}"
            ;;
        --part=*)
            PART="${arg#*=}"
            ;;
        *)
            echo "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

# --- Validate required arguments ---
if [[ -z "$TITLE_NUM" || -z "$MOVIE" ]]; then
    echo "Usage: $0 --dvd-path=/dev/sr0 --title-num=2 --movie=\"Hot Fuzz\""
    exit 1
fi

BASE_PATH="/home/$(whoami)/Videos/Movies"

MOVIE_PATH="${BASE_PATH}/${MOVIE}"

 # Replace spaces with underscore
MOVIE_PATH="${MOVIE_PATH// /_}"

mkdir -p "${MOVIE_PATH}" 

if [ -z "$PART"]; then
  MOVIE+="_part"$PART
fi
FILE_NAME="${MOVIE}.mkv"
OUTPUT="${MOVIE_PATH}/${FILE_NAME}"
OUTPUT="${OUTPUT// /_}"


# Rip Movie
echo "Ripping Title $DVD_TITLE → $OUTPUT"
# Create temproraty FIFO queue for raw data
tempQueue=$(mktemp -u)
mkfifo $tempQueue
echo "Created temporary fifo queue" $tmpDir

# Push raw data to FIFO queue on the background
mpv dvd://$DVD_TITLE --dvd-device=$DVD_PATH --stream-dump=$tempQueue &
#Process FOFO queue data, compress and transcode raw data into .mkv file
#Analyze for 5min to find all subtitles
ffmpeg -analyzeduration 300000000 -probesize 100M -i $tempQueue -map 0:v:0 -map 0:a -map 0:s -c:v h264_nvenc -preset p7 -rc vbr -cq 28 -c:a copy -c:s copy $OUTPUT
#Running ripping and processing in parallel improves efficiency and reduces required storage space as ffmpeg immidiately process the data chuncks from mpv  

#Clean up
rm "${tempQueue}"
echo "Removed temporary files"



