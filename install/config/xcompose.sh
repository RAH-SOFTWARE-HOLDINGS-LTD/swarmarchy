# Set default XCompose that is triggered with CapsLock
tee ~/.XCompose >/dev/null <<EOF
# Run swarmarchy-restart-xcompose to apply changes

# Include fast emoji access
include "%H/.local/share/swarmarchy/default/xcompose"

# Identification
<Multi_key> <space> <n> : "$SWARMARCHY_USER_NAME"
<Multi_key> <space> <e> : "$SWARMARCHY_USER_EMAIL"
EOF
