echo "Fix JetBrains font setting"

if [[ $(swarmarchy-font-current) == JetBrains* ]]; then
  swarmarchy-font-set "JetBrainsMono Nerd Font"
fi
