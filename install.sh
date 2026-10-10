#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -eEo pipefail

# Define Swarmarchy locations.
# SWARMARCHY_PATH is the SOURCE TREE we install FROM, not a runtime location. The
# ISO installer stages it somewhere transient and deletes it afterwards, so honour
# a caller-supplied path instead of forcing it into the user's home -- an installed
# system must never carry the repo. The $HOME default is only for running
# install.sh by hand from a manual checkout.
export SWARMARCHY_PATH="${SWARMARCHY_PATH:-$HOME/.local/share/swarmarchy}"
export SWARMARCHY_INSTALL="$SWARMARCHY_PATH/install"
export SWARMARCHY_INSTALL_LOG_FILE="/var/log/swarmarchy-install.log"
export PATH="$SWARMARCHY_PATH/bin:$PATH"

# Install
source "$SWARMARCHY_INSTALL/helpers/all.sh"
source "$SWARMARCHY_INSTALL/preflight/all.sh"
source "$SWARMARCHY_INSTALL/packaging/all.sh"
source "$SWARMARCHY_INSTALL/config/all.sh"
source "$SWARMARCHY_INSTALL/login/all.sh"
source "$SWARMARCHY_INSTALL/post-install/all.sh"
