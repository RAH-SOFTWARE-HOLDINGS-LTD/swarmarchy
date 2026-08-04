# Customizing Swarmarchy

Everything below lives in **`~/.config/`** (your files, safe to edit). Swarmarchy's
shipped defaults live in **`/usr/share/swarmarchy/default/`** — read them for
reference, but never edit them (a `swarmarchy update` overwrites them).

## The three locations

| Location | What it is | Edit it? |
|---|---|---|
| `~/.config/<app>/…` | **Your** config. This is what actually runs. | ✅ yes |
| `/usr/share/swarmarchy/default/<app>/…` | Shipped defaults. Your `~/.config` files usually `include`/reference these. | ❌ read-only |
| `/etc/skel/.config/<app>/…` | The "factory" seed — copied to a brand-new user, and the source `swarmarchy refresh` restores from. | ❌ read-only |

So: **edit `~/.config`**, reference `/usr/share/swarmarchy/default` to see a default,
and use `/etc/skel` (via `swarmarchy refresh`) to reset something you broke.

## Applying changes after you edit

| You edited… | Apply with |
|---|---|
| `~/.config/sway/*` | `swaymsg reload` |
| `~/.config/waybar/*` | `swarmarchy restart waybar` |
| `~/.config/walker/*` | `swarmarchy restart walker` |
| `~/.config/foot/foot.ini` | `swarmarchy restart terminal` (or open a new window) |
| `~/.config/mako/*` | `swarmarchy restart mako` |

## The main customization points

| Want to change… | Edit | Default to copy from |
|---|---|---|
| Keybindings | `~/.config/sway/bindings.conf` | `/usr/share/swarmarchy/default/sway/bindings.conf` |
| Monitors / resolution | `~/.config/sway/monitors.conf` | — |
| Gaps / borders / look | `~/.config/sway/looknfeel.conf` | — |
| Startup apps | `~/.config/sway/autostart.conf` | `/usr/share/swarmarchy/default/sway/autostart.conf` |
| Status bar | `~/.config/waybar/config.jsonc`, `style.css` | `/usr/share/swarmarchy/default/waybar/` |
| App launcher | `~/.config/walker/config.toml`, `themes/` | `/etc/skel/.config/walker/` |
| Terminal | `~/.config/foot/foot.ini` | `/etc/skel/.config/foot/foot.ini` |
| Lock screen | `~/.config/swaylock/config` | `/etc/skel/.config/swaylock/config` |
| Idle / auto-lock | `~/.config/sway/swayidle.sh` (custom) | — |

**See every customizable file:** `ls /etc/skel/.config/`

## Keybindings (hotkeys)

- **Press `Super+K`** to see all keybindings (searchable). It reads *both* the
  defaults and your `~/.config/sway/bindings.conf`.
- To add/change one: edit `~/.config/sway/bindings.conf`. Put a `## My label`
  comment on the line above your `bindsym` and it shows up in the `Super+K` list.
  The last matching `bindsym` wins, so just add yours below the includes to
  override a default.

## Themes

- List / switch: `swarmarchy theme list`, `swarmarchy theme set "Tokyo Night"`
- Cycle wallpaper: `swarmarchy theme bg next`
- Make your own: copy a theme from `/usr/share/swarmarchy/themes/<name>/` into
  `~/.config/swarmarchy/themes/<your-name>/`, edit its `colors.toml` + per-app
  files, then `swarmarchy theme set "Your Name"`.
- Per-app theme colors are generated into `~/.config/swarmarchy/current/theme/`
  on every `theme set` — don't edit those directly (regenerated); edit the theme.

## Reset something you broke

Restore a config to the shipped default (it backs up your version first):

```bash
swarmarchy refresh --help                 # list per-app reset commands
swarmarchy refresh sway                   # e.g. reset the whole sway config
swarmarchy refresh waybar                 # reset waybar
swarmarchy refresh config foot/foot.ini   # reset any single file by its ~/.config path
```

`swarmarchy refresh config X/Y` copies `/etc/skel/.config/X/Y` → `~/.config/X/Y`
(saving a timestamped `.bak` of yours).

## Discover commands

```bash
swarmarchy                 # top-level command groups
swarmarchy <group> --help  # commands in a group (e.g. swarmarchy refresh --help)
swarmarchy commands        # every command with a one-line summary
```
