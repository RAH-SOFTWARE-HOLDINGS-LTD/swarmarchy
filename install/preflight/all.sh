source $SWARMARCHY_INSTALL/preflight/guard.sh
source $SWARMARCHY_INSTALL/preflight/begin.sh
run_logged $SWARMARCHY_INSTALL/preflight/show-env.sh
run_logged $SWARMARCHY_INSTALL/preflight/pacman.sh
run_logged $SWARMARCHY_INSTALL/preflight/first-run-mode.sh
run_logged $SWARMARCHY_INSTALL/preflight/disable-mkinitcpio.sh
