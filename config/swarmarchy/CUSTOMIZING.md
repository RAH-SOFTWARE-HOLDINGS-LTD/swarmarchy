# Customizing Swarmarchy

Everything below lives in **`~/.config/`** (your files, safe to edit). Swarmarchy's
shipped defaults live in **`/usr/share/swarmarchy/default/`** — read them for
reference, but never edit them (a redeploy with `swarmarchy-dev-deploy` overwrites them).

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
| `~/.config/foot/foot.ini` | open a new window |
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
swarmarchy refresh config --list          # list EVERY restorable file + its exact command
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

## After an install: things to do by hand

Optional, in any order.

- **OneDrive** — the installer asks whether to sync it. If you said yes, a setup window opens
  at first login. If you skipped it, run `swarmarchy setup onedrive` any time; it mounts at
  `~/Onedrive`.
- **Weather cities** — put one city per line in `~/.config/swarmarchy/weather-location`
  (e.g. `Vancouver` then `New York`). The first is shown in the bar, hovering lists every
  city, and clicking shows each forecast. Delete the file to guess from your IP.
- **SSH and GPG keys** — restore `~/.ssh` and `~/.gnupg` first; the clones below need them.
- **Neovim** — `git clone git@github.com:ralphie02/LazyVimRah.git ~/.config/nvim`
- **Obsidian** — clone or copy your vault. *(TODO: add the vault's repo URL or location.)*
- **Dev tools** — `mise use -g node@latest ruby@latest`. Ruby is set to use prebuilt
  binaries (`[settings.ruby] compile = false`).
- **Package publishing** — only if you publish to R2: `rclone config` for a `Swarmarchy:`
  remote. The token can't create buckets, so pass `--s3-no-check-bucket` to `rclone copy`.

### Local overrides a fresh install won't have

These live in `~/.config` on the Yoga and differ from the shipped defaults. Back them up
before reinstalling, or re-create them:

| File | What it does |
|---|---|
| `sway/monitors.conf` | `output * scale 1` plus custom modes and positions for the dock's DP outputs (the default is scale 2) |
| `environment.d/sway.conf` | `WLR_RENDERER=vulkan` for the Adreno Vulkan driver (needs `vulkan-freedreno`, so don't uninstall it) |
| `sway/swayidle.sh` and `systemd/user/swayidle.service` | custom idle daemon: 5-minute lock, blanks only the internal display |
| `sway/looknfeel.conf` | fully opaque windows |
| `sway/autostart.conf` | starts only `elephant`, not a persistent Walker service |

Your git name and email are set by the installer's prompts.
