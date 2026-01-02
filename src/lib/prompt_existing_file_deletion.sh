prompt_existing_file_deletion() {
  if [[ -f "$1" ]]; then
    echo "File at location $1 already exists"
    read -p "Do you want to delete existing file? y/N " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo "Deleting existing file " $1
        rm $1
        return 1
    else
      # Did not remove existing file
      return 2
    fi
  fi
  return 1
}
