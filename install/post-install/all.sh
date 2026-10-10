run_logged $SWARMARCHY_INSTALL/post-install/pacman.sh
source $SWARMARCHY_INSTALL/post-install/allow-reboot.sh
source $SWARMARCHY_INSTALL/post-install/finished.sh

# Last: nothing after this point may reference the source tree.
source $SWARMARCHY_INSTALL/post-install/cleanup-source.sh
