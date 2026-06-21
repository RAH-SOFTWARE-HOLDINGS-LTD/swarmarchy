# Install all base packages
# Strip comment lines/blank lines, then take the first token of each line so inline
# "package  # what it is" documentation comments are ignored.
mapfile -t packages < <(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$SWARMARCHY_INSTALL/swarmarchy-base.packages" | awk '{print $1}')
swarmarchy-pkg-add "${packages[@]}"
