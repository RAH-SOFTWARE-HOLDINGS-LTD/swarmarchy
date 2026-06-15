# Install all base packages
# Strip comment lines/blank lines, then take the first token of each line so inline
# "package  # what it is" documentation comments are ignored.
mapfile -t packages < <(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$OMARCHY_INSTALL/omarchy-base.packages" | awk '{print $1}')
omarchy-pkg-add "${packages[@]}"
