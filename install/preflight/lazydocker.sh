# Ask once whether to install lazydocker, and remember the answer for the rest of
# the install. Sourced (not run_logged) for the same reason as printing.sh: it needs
# a tty for gum confirm.
#
# The answer is exported; packaging/lazydocker.sh installs the package when it is 1.
# Set SWARMARCHY_LAZYDOCKER=1 or =0 beforehand to skip the prompt.

# lazydocker needs a container engine, so it is only offered alongside Podman.
if [[ ${SWARMARCHY_CONTAINERS:-0} != 1 ]]; then
  SWARMARCHY_LAZYDOCKER=0
elif [[ -z ${SWARMARCHY_LAZYDOCKER:-} ]]; then
  if [[ -e /dev/tty ]] && gum confirm \
    --padding "$PADDING" \
    --default=false \
    --affirmative "Install lazydocker" \
    --negative "Skip" \
    "Install lazydocker? A terminal UI for the Podman containers."; then
    SWARMARCHY_LAZYDOCKER=1
  else
    SWARMARCHY_LAZYDOCKER=0
  fi
fi

export SWARMARCHY_LAZYDOCKER

if [[ $SWARMARCHY_LAZYDOCKER == 1 ]]; then
  echo "lazydocker: will be installed"
else
  echo "lazydocker: skipped"
fi
