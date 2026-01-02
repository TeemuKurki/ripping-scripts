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

stream_metadatas(){
    local DVD_TITLE=$1
    metadata_array=()
    # If --no-auto-meta set, skip metadata parse
    if [[ -z "$NO_AUTO_META" ]]; then
        metadata_dump=$(mpv dvd://$DVD_TITLE --dvd-device=$DVD_PATH --vo=null --ao=null --frames=0 --msg-level=all=info)
        #echo $metadata_dump
        mapfile -t subs_array < <(echo "$metadata_dump" | grep "Subs")
        mapfile -t audios_array < <(echo "$metadata_dump" | grep "Audio")


        #TODO: Find language based on text input. (en,fi)
        for i in "${!audios_array[@]}"; do
            line="${audios_array[$i]}"
            lang=$(echo "$line" | grep -oP '(?<=--alang=)[^ ]+')
            if [[ -z "$AUDIO_TRACK" || "$AUDIO_TRACK" -eq "$i" ]]; then
                metadata_array+=("-metadata:s:a:$i language=$lang")
                #TODO: Set flag-default=1 if using $AUDIO_TRACK
            fi
        done

        for j in "${!subs_array[@]}"; do
            if [[ -z "$SUBTITLE_TRACK" || "$SUBTITLE_TRACK" -eq "$j" ]]; then
                line="${subs_array[$j]}"
                lang=$(echo "$line" | grep -oP '(?<=--slang=)[^ ]+')
                metadata_array+=("-metadata:s:s:$j language=$lang")
                #TODO: Set flag-default=1 if using $SUBTITLE_TRACK
            fi
        done
    fi
    printf "%s\n" "${metadata_array[@]}"
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

    AUDIO_MAP=$(create_map $AUDIO_TRACK "a")
    SUB_MAP=$(create_map $SUBTITLE_TRACK "s")

    echo "Ripping Title $DVD_TITLE → $OUTPUT"

    set +e   # disable exit-on-error
    metadatas=$(stream_metadatas $DVD_TITLE)
    #echo $metadatas
    mpv dvd://$DVD_TITLE --dvd-device=$DVD_PATH --stream-dump=$tempQueue &
    mpv_pid=$!
    # analyzeduration == 5 minutes to find subtitles
    ffmpeg -analyzeduration 300000000 -probesize 500M -i $tempQueue -map 0:v -map $AUDIO_MAP -map $SUB_MAP -c:v h264_nvenc -preset p7 -rc vbr -cq 28 -c:a aac -b:a 192k -c:s copy $metadatas $OUTPUT
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
MIN_OUTPUT_SIZE_MB="${args[--min-output-size]}"
NO_AUTO_META="${args[--no-auto-meta]}"
eval "TITLES=(${args[--title]:-})"

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

        track_length_in_min=$((${h:-"0"} * 60 + ${m:-"0"}))

        title=$(awk '{print $2}' <<< $t)
        title="${title%,}" # Remove trailing comma
        chapters=$(awk '{print $6}' <<< $t)
        chapters="${chapters%,}" # Remove trailing comma

        if [[ -n "$m" ]]; then
            # Force base-10 encoding
            m=$((10#$m))
        fi

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
