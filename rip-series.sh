#!/bin/bash

# mpv, ffmpeg, lsdvd

# Exit on error
set -e

create_map() {
    # If length or arguments is >= 2 it means the track value was provided
    if [[ -n "$2"  ]]; then
        map_str="0:$2:$1"
    else
        map_str="0:$2"
    fi
    echo "$map_str"
}


# Default values
DVD_PATH="/dev/sr0"
SHOW=""
DISK_NUM=""
KEY_PATH=""
TRACK_MIN_LENGHT=20
SEASON=1
SUBTITLE_TRACK=""
AUDIO_TRACK=""

# --- Parse named arguments ---
for arg in "$@"; do
    case $arg in
        --path=*)
            DVD_PATH="${arg#*=}"
            ;;
        --show=*)
            SHOW="${arg#*=}"
            ;;
        --season=*)
            SEASON="${arg#*=}"
            ;;
        --disk=*)
            DISC_NUM="${arg#*=}"
            ;;
        --track-min-length=*)
            TRACK_MIN_LENGHT="${arg#*=}"
            ;;
        --subtitle-track=*)
            SUBTITLE_TRACK="${arg#*=}"
            ;;
        --audio-track=*)
            AUDIO_TRACK="${arg#*=}"
            ;;
        *)
            echo "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

# Get episode streams indexes and num of chapters
mapfile -t arr < <(lsdvd $DVD_PATH) 


# --- Validate required arguments ---
if [[ -z "$SHOW" || -z "$SEASON" ]]; then
    echo "Usage: $0 --show=\"Breaking Bad\" --season=1 --disk=1"
    exit 1
fi

DIR_PATH="/home/$(whoami)/Videos/$SHOW/Season_$SEASON" 

DIR_PATH=${DIR_PATH// /_}

mkdir -p "${DIR_PATH}"

# --- Loop over episodes ---
for t in "${arr[@]}"; do
    IFS=: read -r h m s <<< $(awk '{print $4}' <<< $t)
    title=$(awk '{print $2}' <<< $t)
    title="${title%,}" # Remove trailing comma
    chapters=$(awk '{print $6}' <<< $t)
    chapters="${chapters%,}" # Remove trailing comma

    if [[ -n "$m" && ( $h -gt 0 || $m -ge $TRACK_MIN_LENGHT ) ]]; then
        # Transform title to base-10. Remove leading zeros 
        DVD_TITLE=$((10#$title))

        OUTPUT="${SEASON_PATH}/${FILE_NAME}"
        OUTPUT="$DIR_PATH/$SHOW-D$DISC_NUM-T$title.mkv"

        # Create temproraty FIFO queue for raw data
        tempQueue=$(mktemp -u)
        mkfifo $tempQueue
        echo "Created temporary fifo queue" $tempQueue

        AUDIO_MAP=$(create_map $AUDIO_TRACK "a")
        SUB_MAP=$(create_map $SUBTITLE_TRACK "s")

        echo "Ripping Title $DVD_TITLE → $OUTPUT"

        set +e   # disable exit-on-error
        mpv dvd://$DVD_TITLE --dvd-device=$DVD_PATH --stream-dump=$tempQueue &
        ffmpeg -analyzeduration 10000000 -probesize 100M -i $tempQueue -map 0:v -map $AUDIO_MAP -map $SUB_MAP -c:v h264_nvenc -preset p7 -rc vbr -cq 28 -c:a copy -c:s copy $OUTPUT
        if [[ $? -ne 0 ]]; then
            echo "FFmpeg threw error on Title: $title"
        fi
        set -e   # re-enable exit-on-error

        #Clean up
        rm "${tempQueue}"
        echo "Removed temporary files"
    fi
done

echo "✅ Finished ripping $NUM_EPISODES episodes from $DVD_PATH"
