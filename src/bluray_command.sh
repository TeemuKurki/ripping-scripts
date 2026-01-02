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

stream_metadatas(){
    local BD_TITLE=$1 
    metadata_dump=$(mpv bluray://$BD_TITLE --bluray-device=$DVD_PATH  --vo=null --ao=null --frames=0 --msg-level=all=info)
    #echo $metadata_dump
    mapfile -t subs_array < <(echo "$metadata_dump" | grep "Subs")
    mapfile -t audios_array < <(echo "$metadata_dump" | grep "Audio")

    metadata_array=()

    #TODO: Find language based on text input. (en,fi

    for i in "${!audios_array[@]}"; do
        line="${audios_array[$i]}"
        lang=$(echo "$line" | grep -oP '(?<=--alang=)[^ ]+')
        if [[ -z "$AUDIO_TRACK" || "$AUDIO_TRACK" -eq "$i" ]]; then
            metadata_array+=("-metadata:s:a:$i language=$lang")
        fi
    done

    for i in "${!subs_array[@]}"; do
        if [[ -z "$SUBTITLE_TRACK" || "$SUBTITLE_TRACK" -eq "$i" ]]; then
            line="${subs_array[$i]}"
            lang=$(echo "$line" | grep -oP '(?<=--slang=)[^ ]+')
            metadata_array+=("-metadata:s:s:$i language=$lang")
        fi
    done

    printf "%s " "${metadata_array[@]}"
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

    if [[ -n "$m" ]]; then
        # Force base-10 encoding
        m=$((10#$m))
    fi

    title=$(awk '{print $2}' <<< $t)
    chapters=$(awk '{print $6}' <<< $t)
    # Only splice titles that are longer min lenght
    

    if [[ -n "$m" && ( $h -gt 0 || $m -ge $TRACK_MIN_LENGHT ) ]]; then
      playlist=$(awk '{print $12}' <<< $t)
      order=$(echo $playlist | grep -o '[0-9]\+')
      target=$DIR_PATH/$SHOW-D$DISC_NUM-P$order-T$title.mkv
      
      metadatas=$(stream_metadatas $title)
      #echo $metadatas
      # Splice all chapters together in found title stream output to ffmpeg for compression and transcoding it to .mkv file
      bd_splice -t $title -c $(chaper_range $chapters) -k $key_path $DVD_PATH  | ffmpeg  -i - -map 0:v:0 -map 0:a -map 0:s -c:v h264_nvenc -preset p7 -rc vbr -cq 25 -c:a $AUDIO_CODEC -c:s copy $metadatas $target
    fi


    if [[ -s "$target" && $VERIFY_SPEED -gt 0 ]]; then
        echo "Verifying: $target" 
        mpv --speed=$VERIFY_SPEED --vo=null --stream-lavf-o=abort_on_error=yes $target
        if [[ $? -ne 0 ]]; then
            echo "Verification failed for $target"
            if [[ $EXIT_ON_VERIFY_ERR -eq "true" ]]; then
                echo "Exiting on verification error"
                exit 1;
            fi
        fi
    fi
done