# Ask once whether this machine should get printing support, and remember the answer
# for the rest of the install.
#
# This is sourced from preflight/all.sh rather than run through run_logged, because
# run_logged executes scripts as `bash -c "source '$script'" </dev/null` with output
# redirected to the log file -- a script in there has no tty and `gum confirm` cannot
# work. guard.sh and finished.sh are interactive for the same reason.
#
# The answer is exported, so every later `bash -c` subshell inherits it:
#   packaging/printing.sh      installs swarmarchy-printing.packages
#   config/hardware/printer.sh enables cups.service and cups-browsed.service
#
# Set SWARMARCHY_PRINTING=1 or =0 beforehand to skip the prompt on an unattended
# install.

if [[ -z ${SWARMARCHY_PRINTING:-} ]]; then
  if [[ -e /dev/tty ]] && gum confirm \
    --padding "$PADDING" \
    --affirmative "Install printing" \
    --negative "Skip printing" \
    "Set up printer support (CUPS)? Needed only if you print from this machine."; then
    SWARMARCHY_PRINTING=1
  else
    # No tty means no way to ask, so take the lean option rather than pull in ~60MB
    # of print stack on a machine that may never see a printer.
    SWARMARCHY_PRINTING=0
  fi
fi

export SWARMARCHY_PRINTING

if [[ $SWARMARCHY_PRINTING == 1 ]]; then
  echo "Printing: enabled"
else
  echo "Printing: skipped"
fi
