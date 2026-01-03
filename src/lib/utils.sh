string_to_number(){
  local str_num=$1
  local int=0
  if [[ -n $str_num ]]; then
    int=$((10#$str_num))
  fi
  echo $int
}

# Create ffmpeg stream map
create_ffmpeg_map() {
    local map_str=""
    # If length or arguments is >= 2 it means the track value was provided
    if [[ -n "$2"  ]]; then
        map_str="-map 0:$2:$1"
    else
        map_str="-map 0:$1?"
    fi
    echo "$map_str"
}

get_stream_metadatas(){
    local DISK_TYPE=$1 # dvd | bluray
    local DISK_TITLE=$2

    local device=""
    if [[ $DISK_TYPE -eq "bluray" ]]; then
        device="--bluray-device=$DVD_PATH"
    else
        device="--dvd-device=$DVD_PATH"
    fi

    metadata_array=()
    # If --no-auto-meta set, skip metadata parse
    if [[ -z "$NO_AUTO_META" ]]; then
        metadata_dump=$(mpv $DISK_TYPE://$DISK_TITLE $device --vo=null --ao=null --frames=0 --msg-level=all=info)
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