# Parameters
TARGET="${args[target]}"
TRACK="${args[track]}"

eval "META=(${args[--set]:-})"
IS_DIR="false"
IS_FILE="false"

if [[ -d $TARGET ]]; then
    IS_DIR="true"
elif [[ -f $TARGET ]]; then
    IS_FILE="true"
fi

parse_metas(){
  for kv in "${META[@]}"; do
      key=${kv%%=*}
      value=${kv#*=}
      printf -- '--set %s=%s ' "$key" "$value"
  done
  echo
}

set_metadata(){
  local TARGET_FILE=$1
  mkvpropedit $TARGET_FILE --edit track:$TRACK $(parse_metas)
}

if [[ "$IS_DIR" == "true" ]]; then
  echo "Setting metadata to all files: $(parse_metas)"
  mapfile -t files < <(find $TARGET -maxdepth 1 -type f)

  for file in "${files[@]}"; do
      set_metadata $file
  done
elif [[ "$IS_FILE" == "true" ]]; then
echo "Setting metadata to a file: $(parse_metas)"
  set_metadata $TARGET
fi
