# Track if we're already handling an error to prevent double-trapping
ERROR_HANDLING=false

# Cursor is usually hidden while we install
show_cursor() {
  printf "\033[?25h"
}

# Display truncated log lines from the install log
show_log_tail() {
  if [[ -f $SWARMARCHY_INSTALL_LOG_FILE ]]; then
    local log_lines=$((TERM_HEIGHT - LOGO_HEIGHT - 35))
    local max_line_width=$((LOGO_WIDTH - 4))

    tail -n $log_lines "$SWARMARCHY_INSTALL_LOG_FILE" | while IFS= read -r line; do
      if ((${#line} > max_line_width)); then
        local truncated_line="${line:0:$max_line_width}..."
      else
        local truncated_line="$line"
      fi

      gum style "$truncated_line"
    done

    echo
  fi
}

# Display the failed command or script name
show_failed_script_or_command() {
  if [[ -n ${CURRENT_SCRIPT:-} ]]; then
    gum style "Failed script: $CURRENT_SCRIPT"
  else
    # Truncate long command lines to fit the display
    local cmd="$BASH_COMMAND"
    local max_cmd_width=$((LOGO_WIDTH - 4))

    if ((${#cmd} > max_cmd_width)); then
      cmd="${cmd:0:$max_cmd_width}..."
    fi

    gum style "$cmd"
  fi
}

# Save original stdout and stderr for trap to use
save_original_outputs() {
  exec 3>&1 4>&2
}

# Restore stdout and stderr to original (saved in FD 3 and 4)
# This ensures output goes to screen, not log file
restore_outputs() {
  if [[ -e /proc/self/fd/3 ]] && [[ -e /proc/self/fd/4 ]]; then
    exec 1>&3 2>&4
  fi
}

# Paste the log straight away, so the URL is on screen without anyone choosing a menu
# item. The early phases of install_base_system write the log to the live ISO's tmpfs,
# so a reboot before this point destroys it -- uploading unprompted is the only thing
# that reliably gets it off the machine.
#
# Sets UPLOADED_LOG_URL when it works. Never fails the handler: no network, a rate
# limit or a dead endpoint must not stop the menu from appearing.
UPLOADED_LOG_URL=""
upload_log_automatically() {
  if ! swarmarchy-upload-file --check 2>/dev/null; then
    return 0
  fi

  if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
    gum style --foreground 3 "No network, so the log was not uploaded."
    return 0
  fi

  gum style --foreground 8 "Uploading the log..."
  # swarmarchy-upload-log prints the URL indented under a heading, so match the URL
  # itself rather than trusting the last line to be bare.
  UPLOADED_LOG_URL=$(swarmarchy-upload-log install 2>/dev/null |
    grep -oE 'https?://[^[:space:]]+' | tail -n 1) || UPLOADED_LOG_URL=""

  if [[ $UPLOADED_LOG_URL == http* ]]; then
    echo
    gum style --foreground 2 "Log uploaded -- open this on any computer (expires in an hour):"
    gum style --foreground 2 "  $UPLOADED_LOG_URL"
  else
    UPLOADED_LOG_URL=""
    gum style --foreground 3 "Could not upload the log; use the menu to retry."
  fi
  echo
}

# Error handler
catch_errors() {
  # Prevent recursive error handling
  if [[ $ERROR_HANDLING == "true" ]]; then
    return
  else
    ERROR_HANDLING=true
  fi

  # Store exit code immediately before it gets overwritten
  local exit_code=$?

  stop_log_output
  restore_outputs

  clear_logo
  show_cursor

  gum style --foreground 1 --padding "1 0 1 $PADDING_LEFT" "Swarmarchy installation stopped!"
  show_log_tail

  gum style "This command halted with exit code $exit_code:"
  show_failed_script_or_command

  echo
  gum style --foreground 8 "Full log: $SWARMARCHY_INSTALL_LOG_FILE"

  upload_log_automatically

  # Offer options menu
  while true; do
    options=()

    # If online install, show retry first
    if [[ -n ${SWARMARCHY_ONLINE_INSTALL:-} ]]; then
      options+=("Retry installation")
    fi

    # Only offer the upload when the automatic attempt above did not already produce
    # a URL -- otherwise it is on screen and re-pasting just makes a second copy.
    if [[ -z $UPLOADED_LOG_URL ]] && swarmarchy-upload-file --check 2>/dev/null; then
      options+=("Upload log for support")
    fi

    # Add remaining options
    options+=("View full log")
    options+=("Exit")

    choice=$(gum choose "${options[@]}" --header "What would you like to do?" --height 6 --padding "1 $PADDING_LEFT")

    case "$choice" in
    "Retry installation")
      bash "$SWARMARCHY_PATH/install.sh"
      break
      ;;
    "View full log")
      if command -v less &>/dev/null; then
        less "$SWARMARCHY_INSTALL_LOG_FILE"
      else
        tail "$SWARMARCHY_INSTALL_LOG_FILE"
      fi
      ;;
    "Upload log for support")
      swarmarchy-upload-log
      ;;
    "Exit" | "")
      exit 1
      ;;
    esac
  done
}

# Exit handler - ensures cleanup happens on any exit
exit_handler() {
  local exit_code=$?

  # Only run if we're exiting with an error and haven't already handled it
  if (( exit_code != 0 )) && [[ $ERROR_HANDLING != "true" ]]; then
    catch_errors
  else
    stop_log_output
    show_cursor
  fi
}

# Set up traps
trap catch_errors ERR INT TERM
trap exit_handler EXIT

# Save original outputs in case we trap
save_original_outputs
