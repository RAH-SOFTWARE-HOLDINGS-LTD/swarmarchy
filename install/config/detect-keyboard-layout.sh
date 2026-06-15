# Copy the keyboard layout chosen in Arch during install into the Sway config
conf="/etc/vconsole.conf"
swayconf="$HOME/.config/sway/input.conf"

[[ -f $swayconf ]] || exit 0
grep -q '^XKBLAYOUT=' "$conf" || exit 0

layout=$(grep '^XKBLAYOUT=' "$conf" | cut -d= -f2 | tr -d '"')
variant=""
grep -q '^XKBVARIANT=' "$conf" && variant=$(grep '^XKBVARIANT=' "$conf" | cut -d= -f2 | tr -d '"')

# Append an input block so it overrides the default (us) layout in appearance order.
{
  echo ""
  echo "# Keyboard layout detected during install"
  echo "input \"type:keyboard\" {"
  echo "    xkb_layout $layout"
  [[ -n $variant ]] && echo "    xkb_variant $variant"
  echo "}"
} >>"$swayconf"
