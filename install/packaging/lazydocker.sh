# Install lazydocker, if the preflight prompt asked for it.

if [[ ${SWARMARCHY_LAZYDOCKER:-0} != 1 ]]; then
  echo "lazydocker not requested; skipping."
  return 0 2>/dev/null || exit 0
fi

swarmarchy-pkg-add lazydocker
