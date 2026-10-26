# Per-user files copied into the new user's home directory.
# These are all tiny, share a run context (the installing user's $HOME), and must
# land before theme.sh, which links into ~/.config.

# ─── Swarmarchy configs ───────────────────────────────────────────────────────
mkdir -p ~/.config
cp -R "$SWARMARCHY_PATH"/config/* ~/.config/

# Use default bashrc from Swarmarchy
cp "$SWARMARCHY_PATH"/default/bashrc ~/.bashrc

# ─── Branding ─────────────────────────────────────────────────────────────────
# Allow the user to change the branding for fastfetch
mkdir -p ~/.config/swarmarchy/branding
cp "$SWARMARCHY_PATH"/icon.txt ~/.config/swarmarchy/branding/about.txt

# ─── Fonts ────────────────────────────────────────────────────────────────────
# Swarmarchy logo in a font for Waybar use
mkdir -p ~/.local/share/fonts
cp "$SWARMARCHY_PATH"/config/swarmarchy.ttf ~/.local/share/fonts/
fc-cache
