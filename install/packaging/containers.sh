# Install Podman + docker-compose, if the preflight prompt asked for it.
# Same manifest parse as base.sh.

if [[ ${SWARMARCHY_CONTAINERS:-0} != 1 ]]; then
  echo "Containers not requested; skipping."
  return 0 2>/dev/null || exit 0
fi

mapfile -t packages < <(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$SWARMARCHY_INSTALL/swarmarchy-containers.packages" | awk '{print $1}')
swarmarchy-pkg-add "${packages[@]}"
