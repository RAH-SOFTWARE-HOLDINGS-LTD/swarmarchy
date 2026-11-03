# Turn on OneDrive sync for this install, and remember it for the rest of the install.
#
# This is sourced from preflight/all.sh rather than run through run_logged, because
# run_logged executes scripts as `bash -c "source '$script'" </dev/null` with output
# redirected to the log file -- a script in there has no tty and `gum confirm` cannot
# work. guard.sh, printing.sh and finished.sh are interactive for the same reason.
#
# Only the *intent* is captured here. Authorizing the remote needs a browser, and the
# installer runs on a tty before any desktop exists, so config/onedrive.sh records the
# answer as a marker file and first-run/onedrive.sh opens the setup helper once the user
# has a session (and a browser) to sign in with.
#
# rclone itself is unconditional (swarmarchy-base.packages, Files & storage section):
# docs/07 publishes the package repo with it, so it is not OneDrive's to gate.
#
# Set SWARMARCHY_ONEDRIVE=0 beforehand to leave it off.

# OneDrive is on by default; there is no prompt.
SWARMARCHY_ONEDRIVE=${SWARMARCHY_ONEDRIVE:-1}

export SWARMARCHY_ONEDRIVE

if [[ $SWARMARCHY_ONEDRIVE == 1 ]]; then
  echo "OneDrive: enabled"
else
  echo "OneDrive: skipped"
fi
