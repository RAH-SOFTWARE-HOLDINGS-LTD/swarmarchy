# Ask once whether this machine should sync OneDrive, and remember the answer for the
# rest of the install.
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
# Set SWARMARCHY_ONEDRIVE=1 or =0 beforehand to skip the prompt on an unattended install.

if [[ -z ${SWARMARCHY_ONEDRIVE:-} ]]; then
  if [[ -e /dev/tty ]] && gum confirm \
    --padding "$PADDING" \
    --affirmative "Set up OneDrive" \
    --negative "Skip OneDrive" \
    "Set up OneDrive sync at ~/Onedrive? You'll sign in to Microsoft on first login, not now."; then
    SWARMARCHY_ONEDRIVE=1
  else
    # No tty means no way to ask, so take the lean option rather than greet a first
    # login with a sign-in prompt nobody asked for.
    SWARMARCHY_ONEDRIVE=0
  fi
fi

export SWARMARCHY_ONEDRIVE

if [[ $SWARMARCHY_ONEDRIVE == 1 ]]; then
  echo "OneDrive: enabled"
else
  echo "OneDrive: skipped"
fi
