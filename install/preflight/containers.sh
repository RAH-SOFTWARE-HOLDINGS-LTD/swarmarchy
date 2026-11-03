# Ask once whether to install Podman + docker-compose, and remember the answer for
# the rest of the install. Sourced (not run_logged) for the same reason as
# printing.sh: it needs a tty for gum confirm.
#
# The answer is exported:
#   packaging/containers.sh  installs swarmarchy-containers.packages
#   config/system.sh         sets up the subordinate UIDs rootless Podman needs
#   preflight/lazydocker.sh  only offers lazydocker when this is 1
# Set SWARMARCHY_CONTAINERS=1 or =0 beforehand to skip the prompt.

if [[ -z ${SWARMARCHY_CONTAINERS:-} ]]; then
  if [[ -e /dev/tty ]] && gum confirm \
    --padding "$PADDING" \
    --default=false \
    --affirmative "Install containers" \
    --negative "Skip" \
    "Install Podman and docker-compose (rootless containers)?"; then
    SWARMARCHY_CONTAINERS=1
  else
    SWARMARCHY_CONTAINERS=0
  fi
fi

export SWARMARCHY_CONTAINERS

if [[ $SWARMARCHY_CONTAINERS == 1 ]]; then
  echo "Containers: Podman + docker-compose will be installed"
else
  echo "Containers: skipped"
fi
