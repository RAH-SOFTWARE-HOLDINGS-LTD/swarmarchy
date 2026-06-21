echo "Add opencode with system theming"

swarmarchy-pkg-add opencode

# Add config using swarmarchy theme by default
if [[ ! -f ~/.config/opencode/opencode.json ]]; then
  mkdir -p ~/.config/opencode
  cp $SWARMARCHY_PATH/config/opencode/opencode.json ~/.config/opencode/opencode.json
fi
