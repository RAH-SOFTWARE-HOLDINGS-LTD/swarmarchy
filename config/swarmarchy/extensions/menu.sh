# Overwrite parts of the swarmarchy-menu with user-specific submenus.
# See $SWARMARCHY_PATH/bin/swarmarchy-menu for functions that can be overwritten.
#
# WARNING: Overwritten functions will obviously not be updated when Swarmarchy changes.
#
# Example of minimal system menu:
#
# show_system_menu() {
#   case $(menu "System" "  Lock\n󰐥  Shutdown") in
#   *Lock*) swarmarchy-system-lock ;;
#   *Shutdown*) swarmarchy-system-shutdown ;;
#   *) back_to show_main_menu ;;
#   esac
# }
#
# Example of overriding just the about menu action: (Using zsh instead of bash (default))
#
# show_about() {
#   exec swarmarchy-launch-or-focus-tui "zsh -c 'fastfetch; read -k 1'"
# }
