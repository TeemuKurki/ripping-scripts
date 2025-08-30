#!/bin/bash

# bd_list_titles, bd_splice, ffmpeg 

# Default values
DVD_PATH="/dev/sr0"
SHOW=""
DISK_NUM=""
TITLE_NUM=""
KEY_PATH=""
TRACK_MIN_LENGHT=40
SEASON=1
SUBTITLE_TRACK=1
AUDIO_TRACK=1

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
        --title-num=*)
            TITLE_NUM="${arg#*=}"
            ;;
        --key-path=*)
            KEY_PATH="${arg#*=}"
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
mapfile -t arr < <(bd_list_titles $DVD_PATH) 


if [[ ${arr[0]} =~ ^Main[[:space:]]title:\ ([0-9]+) ]]; then
  main_title="${BASH_REMATCH[1]}"
fi

DIR_PATH="/home/$(whoami)/Videos/$SHOW/Season_$SEASON" 

DIR_PATH=${DIR_PATH// /_}

mkdir -p "${DIR_PATH}"

# Extract all episodes
for t in "${arr[@]}"; do
    IFS=: read -r h m s <<< $(awk '{print $4}' <<< $t)
    title=$(awk '{print $2}' <<< $t)
    chapters=$(awk '{print $6}' <<< $t)
    # Only splice titles that are longer than 1 minute
    if [[ -n "$m" && ( $h -gt 0 || $m -gt $TRACK_MIN_LENGHT ) ]]; then
      playlist=$(awk '{print $12}' <<< $t)
      order=$(echo $playlist | grep -o '[0-9]\+')
      echo $order
      #Rip streams
      # Splice all chapters together in found title stream output to ffmpeg for compression and transcoding it to .mkv file
      bd_splice -t $title -c 1-$chapters -k $KEY_PATH $DVD_PATH  | ffmpeg -i - -map 0:v:0 -map 0:a:1 -map 0:s:1 -c:v h264_nvenc -preset p7 -rc vbr -cq 25 -c:a copy -c:s copy $DIR_PATH/$SHOW-D$DISC_NUM-P$order-T$title.mkv
    fi
done

echo $main_title