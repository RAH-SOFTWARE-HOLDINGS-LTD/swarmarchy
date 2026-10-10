# Delete the source tree. An installed system must carry NO copy of the repo.
#
# The repo is a source tree you build/deploy FROM, not a runtime dependency:
# config/deploy.sh has already shipped the output to /usr and /etc/skel, and
# nothing on the running machine reads SWARMARCHY_PATH afterwards. Leaving a
# checkout behind (especially a git one in the user's home) is exactly what this
# install must not do.
#
# To update later, pull the repo from GitHub yourself and run
# `swarmarchy-dev-deploy` from it; it is not needed in between.

# Only remove a tree that really is the source checkout, never a live config dir.
if [[ -n $SWARMARCHY_PATH && -d $SWARMARCHY_PATH/bin && -d $SWARMARCHY_PATH/default && -f $SWARMARCHY_PATH/install.sh ]]; then
  echo "Removing the Swarmarchy source tree from the installed system: $SWARMARCHY_PATH"
  sudo rm -rf "$SWARMARCHY_PATH"
else
  echo "note: \$SWARMARCHY_PATH ('${SWARMARCHY_PATH:-unset}') is not a source tree; nothing removed" >&2
fi

# The installed system must not depend on it either way.
if [[ -e $SWARMARCHY_PATH ]]; then
  echo "WARNING: $SWARMARCHY_PATH still exists after cleanup" >&2
fi
