# Show installation environment variables
gum log --level info "Installation Environment:"

env | grep -E "^(SWARMARCHY_CHROOT_INSTALL|SWARMARCHY_ONLINE_INSTALL|SWARMARCHY_USER_NAME|SWARMARCHY_USER_EMAIL|USER|HOME|SWARMARCHY_REPO|SWARMARCHY_REF|SWARMARCHY_PATH)=" | sort | while IFS= read -r var; do
  gum log --level info "  $var"
done
