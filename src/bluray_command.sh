#!/bin/bash

# bd_list_titles, bd_splice, ffmpeg 

output_path(){
    if [[ -n "$IS_SHOW" ]]; then
        echo "$HOME/Videos/$SHOW/Season_$SEASON" 
    else
        echo "$HOME/Videos/$SHOW" 
    fi
}

chaper_range(){
    local chapters=$1
    if [[ $chapters -eq "1" ]]; then
        echo "1"
    else
        echo "1-$chapters"
    fi
}

# Default values
DVD_PATH="${args[--disk-path]}"
IS_SHOW="${args[--show]}"
SHOW="${args[title]}"
KEY_PATH="${args[--key]}"
TRACK_MIN_LENGHT="${args[--min-length]}"
SEASON="${args[--season]}"
DISK_NUM="${args[--disk]}"
AUDIO_CODEC="${args[--audio-codec]}"
VERIFY_SPEED="${args[--verify-speed]}"
EXIT_ON_VERIFY_ERR="${args[--exit-on-verify-error]}"

AUDIO_TRACK="${args[--audio-track]}"
SUBTITLE_TRACK="${args[--subtitle-track]}"
VIDEO_TRACK="${args[--video-track]}"
VIDEO_ENCODING_PARAMS="${args[--video-encoding-params]}"

# Get episode streams indexes and num of chapters
mapfile -t arr < <(bd_list_titles $DVD_PATH) 

DIR_PATH=$(output_path)

SHOW=${SHOW// /_}
DIR_PATH=${DIR_PATH// /_}

mkdir -p "${DIR_PATH}"

key_path=$(readlink -m $KEY_PATH)

# Extract all episodes
for t in "${arr[@]}"; do
    IFS=: read -r h m s <<< $(awk '{print $4}' <<< $t)
    minutes=$(string_to_number $m)
    hours=$(string_to_number $h)

    track_length_in_min=$(($hours * 60 + $minutes))

    title=$(awk '{print $2}' <<< $t)
    chapters=$(awk '{print $6}' <<< $t)
    
    AUDIO_MAP=$(create_ffmpeg_map $AUDIO_TRACK "a")
    SUB_MAP=$(create_ffmpeg_map $SUBTITLE_TRACK "s")
    VIDEO_MAP=$(create_ffmpeg_map $VIDEO_TRACK "v")

    # Only splice titles that are longer min lenght
    if [[ $track_length_in_min -ge $TRACK_MIN_LENGHT ]]; then
      playlist=$(awk '{print $12}' <<< $t)
      order=$(echo $playlist | grep -o '[0-9]\+')
      target=$DIR_PATH/$SHOW-D$DISK_NUM-P$order-T$title.mkv
      
      set +e
      prompt_existing_file_deletion "$target"
      resp=$?
      set -e
      # Only rip if prompt answer is 1 (no conflict or conflict deleted)
      if [[ $resp -eq 1 ]]; then
        metadatas=$(get_stream_metadatas "bluray" $title)
        # Splice all chapters together in found title stream output to ffmpeg for compression and transcoding it to .mkv file
        bd_splice -t $title -c $(chaper_range $chapters) -k $key_path $DVD_PATH  | ffmpeg -i - $VIDEO_MAP $AUDIO_MAP $SUB_MAP $VIDEO_ENCODING_PARAMS -c:a $AUDIO_CODEC -c:s copy $metadatas $target

        if [[ -s "$target" && $VERIFY_SPEED -gt 0 ]]; then
          echo "Verifying: $target" 
          mpv --speed=$VERIFY_SPEED --vo=null --stream-lavf-o=abort_on_error=yes $target
          if [[ $? -ne 0 ]]; then
            echo "Verification failed for $target"
            if [[ -n "$EXIT_ON_VERIFY_ERR" ]]; then
              echo "Exiting on verification error"
              exit 1;
            fi
          fi
        fi
      fi
    fi
done