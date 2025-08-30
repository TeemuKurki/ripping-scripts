#!/bin/bash

#Using: vlc, lsdvd, ffmpeg

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
tmpDir=$(mktemp -d -p ~)
echo "Created temporary directory" $tmpDir
mpv dvd://$DVD_TITLE --dvd-device=$DVD_PATH --stream-dump=$tmpDir/dvdstream.vob
#Analyze for 5min to find all subtitles
ffmpeg -analyzeduration 300000000 -probesize 100M -i $tmpDir/dvdstream.vob -map 0:v:0 -map 0:a -map 0:s -c:v h264_nvenc -preset p7 -rc vbr -cq 28 -c:a copy -c:s copy $OUTPUT
rm $tmpDir/dvdstream.vob
rmdir $tmpDir
echo "Remove temp files and folders"



