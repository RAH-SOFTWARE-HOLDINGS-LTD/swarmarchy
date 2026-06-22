SWARMARCHY_MIGRATIONS_STATE_PATH=~/.local/state/swarmarchy/migrations
mkdir -p $SWARMARCHY_MIGRATIONS_STATE_PATH

for file in ~/.local/share/swarmarchy/migrations/*.sh; do
  [ -e "$file" ] || continue
  touch "$SWARMARCHY_MIGRATIONS_STATE_PATH/$(basename "$file")"
done
