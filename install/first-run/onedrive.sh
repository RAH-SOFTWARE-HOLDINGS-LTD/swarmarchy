# Finish OneDrive setup now that there is a login session -- and therefore a browser to
# sign in to Microsoft with, which the installer did not have. Run by swarmarchy-first-run.
#
# The marker comes from install/config/onedrive.sh, which records the answer to the
# preflight prompt. The authorized-remote check comes first so that reinstalling over an
# existing home (or restoring an rclone.conf) just brings the mount back up instead of
# asking the user to sign in again.

MARKER=~/.local/state/swarmarchy/onedrive.wanted

if rclone listremotes 2>/dev/null | grep -qx 'onedrive:'; then
  rm -f "$MARKER"
  systemctl --user enable --now onedrive-mount.service
elif [[ -f $MARKER ]]; then
  rm -f "$MARKER"
  swarmarchy-launch-floating-terminal-with-presentation swarmarchy-setup-onedrive
fi
