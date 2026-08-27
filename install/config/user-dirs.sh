mkdir -p ~/Projects ~/Downloads ~/Media ~/.config/gtk-3.0

xdg-user-dirs-update --set TEMPLATES "$HOME/Desktop"
xdg-user-dirs-update --set PUBLICSHARE "$HOME/Desktop"

rmdir ~/Templates ~/Public 2>/dev/null || true

touch ~/.config/gtk-3.0/bookmarks
for dir in Desktop Downloads Media Projects; do
  printf 'file://%s/%s %s\n' "$HOME" "$dir" "$dir" >>~/.config/gtk-3.0/bookmarks
done
