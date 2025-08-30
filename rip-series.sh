#!/bin/bash

# mpv, ffmpeg, libdvdcss2

# Exit on error
set -e

# Default values
DVD_PATH="/dev/sr0"
NUM_EPISODES=""
SERIES=""
SEASON=""
START_EPISODE=""
TITLE_NUM=""
VIDEO_CODEC="h264"
RES_WIDTH="720"
RES_HEIGHT="576"
VIDEO_BITRATE="1500"
AUDIO_CODEC="mp4a"
AUDIO_CHANNELS="2"
AUDIO_SAMPLERATE="44100"
AUDIO_BITRATE="192"
AUDIO_CODEC="mp4a"
SUBTITLE_CODEC="dvbs"
MUX="mp4"
OUTPUT_FILE_EXT="mp4"

QUALITY=25

# --- Parse named arguments ---
for arg in "$@"; do
    case $arg in
        --dvd-path=*)
            DVD_PATH="${arg#*=}"
            ;;
        --num-of-episodes=*)
            NUM_EPISODES="${arg#*=}"
            ;;
        --series=*)
            SERIES="${arg#*=}"
            ;;
        --season=*)
            SEASON="${arg#*=}"
            ;;
        --starting-episode=*)
            START_EPISODE="${arg#*=}"
            ;;
        --title-num=*)
            TITLE_NUM="${arg#*=}"
            ;;
        --video-codec=*)
            VIDEO_CODEC="${arg#*=}"
            ;;
        --width=*)
            RES_WIDTH="${arg#*=}"
            ;;
        --height=*)
            RES_HEIGHT="${arg#*=}"
            ;;
        --video-bitrate=*)
            VIDEO_BITRATE="${arg#*=}"
            ;;
        --audio-codec=*)
            AUDIO_CODEC="${arg#*=}"
            ;;
        --audio-channels=*)
            AUDIO_CHANNELS="${arg#*=}"
            ;;
        --audio-samplerate=*)
            AUDIO_SAMPLERATE="${arg#*=}"
            ;;
        --audio-codec=*)
            AUDIO_CODEC="${arg#*=}"
            ;;
        --subtitle-codec=*)
            SUBTITLE_CODEC="${arg#*=}"
            ;;
        --mux=*)
            MUX="${arg#*=}"
            ;;
        --output-file-ext=*)
            OUTPUT_FILE_EXT="${arg#*=}"
            ;;
        --quality=*)
            QUALITY="${arg#*=}"
            ;;
        *)
            echo "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

# --- Validate required arguments ---
if [[ -z "$NUM_EPISODES" || -z "$TITLE_NUM" || -z "$SERIES" || -z "$SEASON" || -z "$START_EPISODE" ]]; then
    echo "Usage: $0 --dvd-path=/dev/sr0 --num-of-episodes=3 --title-num=2 --series=\"Breaking Bad\" --season=1 --starting-episode=4"
    exit 1
fi

BASE_PATH="/home/teemu/Videos"

SERIES_PATH="${BASE_PATH}/${SERIES}"
SEASON_PATH="${SERIES_PATH}/Season ${SEASON}"
 # Replace spaces with underscore
SEASON_PATH="${SEASON_PATH// /_}"

mkdir -p "${SEASON_PATH}" 

# --- Loop over episodes ---
for ((i=0; i<NUM_EPISODES; i++)); do
    EPISODE_NUM=$((START_EPISODE + i))
    DVD_TITLE=$((TITLE_NUM + i))
    FILE_NAME="${SERIES}_S${SEASON}E${EPISODE_NUM}.mkv"
    OUTPUT="${SEASON_PATH}/${FILE_NAME}"
    OUTPUT="${OUTPUT// /_}"

    echo "Ripping Title $DVD_TITLE → $OUTPUT"
    tmpDir=$(mktemp -d)
    echo "Created temporary directory" $tmpDir

    #TODO: Look if it's possible to stream mpv stream directly to ffmpeg

    mpv dvd://$DVD_TITLE --dvd-device=$DVD_PATH --stream-dump=$tmpDir/dvdstream.vob
    ffmpeg -analyzeduration 10000000 -i $tmpDir/dvdstream.vob -map 0:v:0 -map 0:a -map 0:s -c:v h264_nvenc -preset p7 -rc vbr -cq 28 -c:a copy -c:s copy $OUTPUT
    rm $tmpDir/dvdstream.vob
    rmdir $tmpDir
    echo "Remove temp files and folders"
done

echo "✅ Finished ripping $NUM_EPISODES episodes from $DVD_PATH"
