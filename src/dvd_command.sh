#!/bin/bash

# mpv, ffmpeg, lsdvd

# Exit on error
set -e

output_path(){
    if [[ -n "$IS_SHOW" ]]; then
        echo "$HOME/Videos/$SHOW/Season_$SEASON" 
    else
        echo "$HOME/Videos/$SHOW" 
    fi
}

rip_video(){
    local DVD_TITLE=$1 

    OUTPUT="$DIR_PATH/$SHOW-D$DISK_NUM-T$DVD_TITLE.mkv"
    OUTPUT=${OUTPUT// /_}

    set +e
    prompt_existing_file_deletion "$OUTPUT"
    resp=$?
    set -e
    if [[ $resp -eq 2 ]]; then
        # Exit early if output file already exists and did not delete
        return 0
    fi

    # Create temproraty FIFO queue for raw data
     # Create temp directory
    tempdir="$(mktemp -d)"
    tempQueue="$tempdir/stream.fifo"

    cleanup() {
        # Kill background mpv if still running
        if [[ -n "$mpv_pid" ]] && kill -0 "$mpv_pid" 2>/dev/null; then
            kill "$mpv_pid" 2>/dev/null
        fi

        # Remove FIFO and temp dir
        [[ -p "$tempQueue" ]] && rm -f "$tempQueue"
        [[ -d "$tempdir" ]] && rmdir "$tempdir" 2>/dev/null
    }

    # Always run cleanup when function exits (success, failure, ctrl+c, kill)
    trap cleanup EXIT SIGINT SIGTERM

    mkfifo $tempQueue
    echo "Created temporary fifo queue" $tempQueue

    AUDIO_MAP=$(create_ffmpeg_map $AUDIO_TRACK "a")
    SUB_MAP=$(create_ffmpeg_map $SUBTITLE_TRACK "s")
    VIDEO_MAP=$(create_ffmpeg_map $VIDEO_TRACK "v")

    echo "Ripping Title $DVD_TITLE → $OUTPUT"

    set +e   # disable exit-on-error
    metadatas=$(get_stream_metadatas "dvd" $DVD_TITLE)
    #echo $metadatas
    mpv dvd://$DVD_TITLE --dvd-device=$DVD_PATH --stream-dump=$tempQueue &
    mpv_pid=$!
    # analyzeduration == 5 minutes to find subtitles
    ffmpeg -analyzeduration 300000000 -probesize 500M -i $tempQueue $VIDEO_MAP $AUDIO_MAP $SUB_MAP $VIDEO_ENCODING_PARAMS -c:a $AUDIO_CODEC -c:s copy $metadatas $OUTPUT
    if [[ $? -ne 0 ]]; then
        echo "FFmpeg threw error on Title: $title"
    fi

    if [[ -s "$OUTPUT" && $VERIFY_SPEED -gt 0 ]]; then
        echo "Verifying " $OUTPUT 
        mpv --speed=$VERIFY_SPEED --vo=null --stream-lavf-o=abort_on_error=yes $OUTPUT
        if [[ $? -ne 0 ]]; then
            echo "Verification failed for $OUTPUT"
            if [[ -n "$EXIT_ON_VERIFY_ERR" ]]; then
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
            echo "Ripped file size less than $MIN_OUTPUT_SIZE_MB MB. Removing: $OUTPUT"
            rm $OUTPUT  
        fi
    fi
}

# Default values
DVD_PATH="${args[--disk-path]}"
IS_SHOW="${args[--show]}"
SHOW="${args[title]}"
TRACK_MIN_LENGHT="${args[--min-length]}"
TRACK_MAX_LENGHT="${args[--max-length]}"
SEASON="${args[--season]}"
DISK_NUM="${args[--disk]}"
AUDIO_CODEC="${args[--audio-codec]}"
VERIFY_SPEED="${args[--verify-speed]}"
EXIT_ON_VERIFY_ERR="${args[--exit-on-verify-error]}"
AUDIO_TRACK="${args[--audio-track]}"
SUBTITLE_TRACK="${args[--subtitle-track]}"
VIDEO_TRACK="${args[--video-track]}"
MIN_OUTPUT_SIZE_MB="${args[--min-output-size]}"
NO_AUTO_META="${args[--no-auto-meta]}"
eval "TITLES=(${args[--title]:-})"
VIDEO_ENCODING_PARAMS="${args[--video-encoding-params]}"

# Get episode streams indexes and num of chapters

mapfile -t arr < <(lsdvd $DVD_PATH) 

SHOW=${SHOW// /_}
DIR_PATH=$(output_path)
DIR_PATH=${DIR_PATH// /_}

mkdir -p "${DIR_PATH}"

if [[ -n $TITLES ]]; then
    for t in "${TITLES[@]}"; do
        DVD_TITLE=$((10#$t))
        rip_video $DVD_TITLE
    done

elif [[ -n $IS_SHOW ]]; then
    # --- Loop over episodes ---
    for t in "${arr[@]}"; do
        IFS=: read -r h m s <<< $(awk '{print $4}' <<< $t)
        minutes=$(string_to_number $m)
        hours=$(string_to_number $h)

        track_length_in_min=$(($hours * 60 + $minutes))

        title=$(awk '{print $2}' <<< $t)
        title="${title%,}" # Remove trailing comma
        chapters=$(awk '{print $6}' <<< $t)
        chapters="${chapters%,}" # Remove trailing comma

        if [[ $track_length_in_min -ge $TRACK_MIN_LENGHT && ($TRACK_MAX_LENGHT -eq 0 || $track_length_in_min -le $TRACK_MAX_LENGHT)  ]]; then
            # Transform title to base-10. Remove leading zeros 
            DVD_TITLE=$((10#$title))
            rip_video $DVD_TITLE
        fi
    done
else
    rip_video
fi
echo "Finished ripping $NUM_EPISODES episodes from $DVD_PATH"
