# Record the OneDrive choice from preflight/onedrive.sh for first-run to act on.
#
# A marker file rather than an env var, because the answer has to survive the reboot
# between the install and the first login -- authorizing the remote needs a browser, so
# first-run/onedrive.sh is what finishes the job.
#
# Runs after config/home.sh, which is what puts config/systemd/user/onedrive-mount.service
# into ~/.config/systemd/user/.

if [[ ${SWARMARCHY_ONEDRIVE:-0} == 1 ]]; then
  mkdir -p ~/.local/state/swarmarchy
  touch ~/.local/state/swarmarchy/onedrive.wanted
  echo "OneDrive: setup queued for first login"
fi
