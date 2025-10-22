#!/bin/bash

# mpv, ffmpeg, lsdvd

# Exit on error
set -e

create_map() {
    # If length or arguments is >= 2 it means the track value was provided
    if [[ -n "$2"  ]]; then
        map_str="0:$2:$1"
    else
        map_str="0:$1?"
    fi
    echo "$map_str"
}

output_path(){
    if [[ -n "$IS_SHOW" ]]; then
        echo "$HOME/Videos/$SHOW/Season_$SEASON" 
    else
        echo "$HOME/Videos/$SHOW" 
    fi
}

rip_video(){
    local DVD_TITLE=$1 

    OUTPUT="$DIR_PATH/$SHOW-D$DISC_NUM-T$title.mkv"
    OUTPUT=${OUTPUT// /_}


    # Create temproraty FIFO queue for raw data
    tempQueue=$(mktemp -u)
    mkfifo $tempQueue
    echo "Created temporary fifo queue" $tempQueue

    AUDIO_MAP=$(create_map $AUDIO_TRACK "a")
    SUB_MAP=$(create_map $SUBTITLE_TRACK "s")

    echo "Ripping Title $DVD_TITLE → $OUTPUT"

    set +e   # disable exit-on-error
    mpv dvd://$DVD_TITLE --dvd-device=$DVD_PATH --stream-dump=$tempQueue &
    # analyzeduration == 5 minutes to find subtitles
    ffmpeg -analyzeduration 300000000 -probesize 500M -i $tempQueue -map 0:v -map $AUDIO_MAP -map $SUB_MAP -c:v h264_nvenc -preset p7 -rc vbr -cq 28 -c:a copy -c:s copy $OUTPUT
    if [[ $? -ne 0 ]]; then
        echo "FFmpeg threw error on Title: $title"
    fi

    if [[ -s "$OUTPUT" && $VERIFY_SPEED -gt 0 ]]; then
        echo "Verifying " $OUTPUT 
        mpv --speed=$VERIFY_SPEED --vo=null --stream-lavf-o=abort_on_error=yes $OUTPUT
        if [[ $? -ne 0 ]]; then
            echo "Verification failed for $OUTPUT"
            if [[ $EXIT_ON_VERIFY_ERR -eq "true" ]]; then
                echo "Exiting on verification error"
                exit 1;
            fi
        fi
    fi


    # Could use ffprobe to check movie duration to remove duplicate multiple episodes in single mkv file
    if [[ -e $OUTPUT ]]; then
        outputSize=$(stat $OUTPUT -c %s)
        if [[  $outputSize -lt $(($MIN_OUTPUT_SIZE_MB * 1000000)) ]]; then
            # Remove ouput file if its less than $MIN_OUTPUT_SIZE_MB to clear menu files etc.
            echo "Removing: $OUTPUT"
            rm $OUTPUT  
        fi
    fi

}

# Default values
DVD_PATH="${args[--disk-path]}"
IS_SHOW="${args[--show]}"
SHOW="${args[title]}"
TRACK_MIN_LENGHT="${args[--min-length]}"
SEASON="${args[--season]}"
DISK_NUM="${args[--disk]}"
AUDIO_CODEC="${args[--audio-codec]}"
VERIFY_SPEED="${args[--verify-speed]}"
EXIT_ON_VERIFY_ERR="${args[--exit-on-verify-error]}"
AUDIO_TRACK="${args[--audio-track]}"
SUBTITLE_TRACK="${args[--subtitle-track]}"
MIN_OUTPUT_SIZE_MB="${args[--min-output-size]}"


# Get episode streams indexes and num of chapters

mapfile -t arr < <(lsdvd $DVD_PATH) 

SHOW=${SHOW// /_}
DIR_PATH=$(output_path)
DIR_PATH=${DIR_PATH// /_}

mkdir -p "${DIR_PATH}"
if [[ -n $IS_SHOW ]]; then
    # --- Loop over episodes ---
    for t in "${arr[@]}"; do
        IFS=: read -r h m s <<< $(awk '{print $4}' <<< $t)
        title=$(awk '{print $2}' <<< $t)
        title="${title%,}" # Remove trailing comma
        chapters=$(awk '{print $6}' <<< $t)
        chapters="${chapters%,}" # Remove trailing comma



        if [[ -n "$m" ]]; then
            # Force base-10 encoding
            m=$((10#$m))
        fi

        if [[ -n "$m" && ( $h -gt 0 || $m -ge $TRACK_MIN_LENGHT ) ]]; then
            # Transform title to base-10. Remove leading zeros 
            DVD_TITLE=$((10#$title))
            rip_video $DVD_TITLE
        fi
    done
else
    rip_video
fi
echo "✅ Finished ripping $NUM_EPISODES episodes from $DVD_PATH"
