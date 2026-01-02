validate_dir_or_file_exists() {
  if [[ ! -d "$1" ]] && [[ ! -f "$1" ]]; then
    echo "must be an existing file or directory"
  fi
}
