echo "Seed the walker theme into ~/.config so its color @import resolves"

# The walker theme moved from /usr/share (shared, read-only) to ~/.config
# (per-user): its style.css @imports the per-user generated color file
# (~/.config/swarmarchy/current/theme/walker.css), and a copy sitting in /usr can't
# reach that with a relative path -- which is why the launcher rendered transparent
# with no visible selection after the "install to /usr" change. New users get the
# theme via /etc/skel; this seeds existing installs. Nothing here clobbers an
# existing ~/.config copy.
skel=/etc/skel/.config/walker/themes/swarmarchy-default
dst="$HOME/.config/walker/themes/swarmarchy-default"
if [[ ! -d $dst && -d $skel ]]; then
  mkdir -p "$HOME/.config/walker/themes"
  cp -r "$skel" "$dst"
fi

# Repoint walker at the per-user themes dir, but only if it still targets the old
# shared /usr location (don't clobber a value you set by hand).
cfg="$HOME/.config/walker/config.toml"
if [[ -f $cfg ]] && grep -q '^additional_theme_location = "/usr/share/swarmarchy' "$cfg"; then
  sed -i 's#^additional_theme_location = .*#additional_theme_location = "~/.config/walker/themes/"#' "$cfg"
fi
