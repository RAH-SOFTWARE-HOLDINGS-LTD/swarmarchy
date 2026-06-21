# Place in each assistant's global skills directory so the Swarmarchy skill is available on first install
mkdir -p ~/.agents/skills ~/.claude/skills ~/.codex/skills ~/.pi/agent/skills
ln -sfn "$SWARMARCHY_PATH/default/swarmarchy-skill" ~/.agents/skills/swarmarchy
ln -sfn "$SWARMARCHY_PATH/default/swarmarchy-skill" ~/.claude/skills/swarmarchy
ln -sfn "$SWARMARCHY_PATH/default/swarmarchy-skill" ~/.codex/skills/swarmarchy
ln -sfn "$SWARMARCHY_PATH/default/swarmarchy-skill" ~/.pi/agent/skills/swarmarchy
