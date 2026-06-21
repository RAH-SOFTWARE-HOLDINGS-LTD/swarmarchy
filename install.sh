#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -eEo pipefail

# Define Swarmarchy locations
export SWARMARCHY_PATH="$HOME/.local/share/swarmarchy"
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
