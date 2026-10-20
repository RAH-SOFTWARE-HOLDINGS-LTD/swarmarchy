# Install the optional printing stack, if the preflight prompt asked for it.
# Same manifest parse as base.sh: drop comment/blank lines, keep the first token so
# inline "package  # what it is" documentation is ignored.

if [[ ${SWARMARCHY_PRINTING:-0} != 1 ]]; then
  echo "Printing not requested; skipping the CUPS stack."
  return 0 2>/dev/null || exit 0
fi

mapfile -t packages < <(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$SWARMARCHY_INSTALL/swarmarchy-printing.packages" | awk '{print $1}')
swarmarchy-pkg-add "${packages[@]}"
