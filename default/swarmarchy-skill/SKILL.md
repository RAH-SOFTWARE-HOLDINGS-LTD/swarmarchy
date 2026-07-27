---
name: swarmarchy
description: >
  REQUIRED for end-user customization of Linux desktop, window manager, or system config.
  Use when editing ~/.config/sway/, ~/.config/waybar/, ~/.config/walker/,
  ~/.config/foot/, ~/.config/mako/, ~/.config/swaylock/,
  or ~/.config/swarmarchy/. Triggers: Sway, window rules, keybindings,
  monitors, gaps, borders, opacity, waybar, walker, terminal config, themes,
  wallpaper, night light, idle, lock screen, screenshots, reminders,
  workspace settings, display config, and user-facing swarmarchy commands. Excludes Swarmarchy
  source development in /usr/share/swarmarchy/ and `swarmarchy dev` workflows.
---

# Swarmarchy Skill

Manage Swarmarchy Linux systems - an opinionated Arch Linux (aarch64) desktop running Sway.

This skill is for end-user customization on installed systems.
It is not for contributing to Swarmarchy source code.

## When This Skill MUST Be Used

**ALWAYS invoke this skill for end-user requests involving ANY of these:**

- Editing ANY file in `~/.config/sway/` (window rules, keybindings, monitors, etc.)
- Editing ANY file in `~/.config/waybar/`, `~/.config/walker/`, `~/.config/mako/`
- Editing the terminal config (foot)
- Editing ANY file in `~/.config/swarmarchy/`
- Window behavior, opacity, gaps, borders
- Workspace settings, display/monitor configuration
- Themes, wallpapers, fonts, appearance changes
- User-facing `swarmarchy` commands (`swarmarchy theme ...`, `swarmarchy refresh ...`, `swarmarchy restart ...`, etc.)
- Screenshots, screen recording, reminders, night light, idle behavior, lock screen

**If you're about to edit a config file in ~/.config/ on this system, STOP and use this skill first.**

**Do NOT use this skill for Swarmarchy development tasks** (editing files in `/usr/share/swarmarchy/`, creating migrations, or running `swarmarchy dev ...` workflows).

## Critical Safety Rules

**For end-user customization tasks, NEVER modify anything in `/usr/share/swarmarchy/`** - but READING is safe and encouraged.

This directory contains Swarmarchy's source files managed by git. Any changes will be:
- Lost on next `swarmarchy update`
- Cause conflicts with upstream
- Break the system's update mechanism

```
/usr/share/swarmarchy/     # READ-ONLY - NEVER EDIT (reading is OK)
├── bin/                    # Source scripts (symlinked to PATH)
├── config/                 # Default config templates
├── themes/                 # Stock themes
├── default/                # System defaults
└── install/                # Installation scripts
```

**Reading `/usr/share/swarmarchy/` is SAFE and useful** - do it freely to:
- Understand how swarmarchy commands work: `swarmarchy theme set --help` or `cat $(which swarmarchy-theme-set)`
- See default configs before customizing: `cat /usr/share/swarmarchy/config/waybar/config.jsonc`
- Check stock theme files to copy for customization
- Reference default Sway settings: `cat /usr/share/swarmarchy/default/sway/*`

**Always use these safe locations instead:**
- `~/.config/` - User configuration (safe to edit)
- `~/.config/swarmarchy/themes/<custom-name>/` - Custom themes (must be real directories)
- `~/.config/swarmarchy/hooks/` - Custom automation hooks

If the request is to develop Swarmarchy itself, this skill is out of scope. Follow repository development instructions instead of this skill.

## System Architecture

Swarmarchy is built on:

| Component | Purpose | Config Location |
|-----------|---------|-----------------|
| **Arch Linux** | Base OS | `/etc/`, `~/.config/` |
| **Sway** | Wayland compositor/WM | `~/.config/sway/` |
| **Waybar** | Status bar | `~/.config/waybar/` |
| **Walker** | App launcher | `~/.config/walker/` |
| **Foot** | Terminal | `~/.config/foot/` |
| **Mako** | Notifications | `~/.config/mako/` |
| **SwayOSD** | On-screen display | `~/.config/swayosd/` |

## Command Discovery

Swarmarchy ships a single `swarmarchy` CLI that dispatches to all `swarmarchy-*` binaries via `swarmarchy <group> <action>`. Always prefer this form — it is self-documenting and stable. The underlying `swarmarchy-*` binaries still exist on `PATH` and remain safe to read for source.

```bash
# List every documented command and its summary
swarmarchy commands

# Show the commands inside a group
swarmarchy theme --help
swarmarchy refresh --help
swarmarchy restart --help

# Show help for a specific command (does not execute it)
swarmarchy theme set --help

# Machine-readable listing (binary, route, summary, args, aliases)
swarmarchy commands --json

# Read a command's source to understand it
cat $(which swarmarchy-theme-set)
```

### Command Groups

Run `swarmarchy --help` for the full list. The most common groups:

| Group | Purpose | Example |
|-------|---------|---------|
| `swarmarchy refresh` | Reset config to defaults (backs up first) | `swarmarchy refresh waybar` |
| `swarmarchy restart` | Restart a service/app | `swarmarchy restart waybar` |
| `swarmarchy toggle` | Toggle feature on/off | `swarmarchy toggle nightlight` |
| `swarmarchy theme` | Theme management | `swarmarchy theme set <name>` |
| `swarmarchy install` | Install optional software / packages | `swarmarchy install docker dbs` |
| `swarmarchy launch` | Launch apps | `swarmarchy launch browser` |
| `swarmarchy capture` | Screenshots and recordings | `swarmarchy capture screenshot` |
| `swarmarchy reminder` | Desktop notification reminders | `swarmarchy reminder 15 "Pickup Jack"` |
| `swarmarchy pkg` | Package management | `swarmarchy pkg install <pkg>` |
| `swarmarchy setup` | Initial setup tasks | `swarmarchy setup fingerprint` |
| `swarmarchy update` | System updates | `swarmarchy update` |

## Configuration Locations

### Sway (Window Manager)

```
~/.config/sway/
├── config             # Main config (includes the others + defaults)
├── bindings.conf      # Keybindings
├── monitors.conf      # Display/output configuration
├── input.conf         # Keyboard/mouse/touchpad settings
├── looknfeel.conf     # Appearance (gaps, borders)
└── autostart.conf     # Startup applications
```

Idle, lock, and night light live outside the Sway config: idle via `swayidle`
(`swarmarchy-swayidle`), lock via `~/.config/swaylock/config`, night light via
`wlsunset` (`swarmarchy toggle nightlight`).

**Key behaviors:**
- Sway does NOT auto-reload on save — run `swaymsg reload` after editing.
- Validate a config with `sway --validate`; Sway reports config errors in its
  log (and as a notification) on reload.
- Use `swarmarchy refresh sway` to reset the Sway config to defaults.

### Waybar (Status Bar)

```
~/.config/waybar/
├── config.jsonc       # Bar layout and modules (JSONC format)
└── style.css          # Styling
```

**Waybar does NOT auto-reload.** You MUST run `swarmarchy restart waybar` after any config changes.

**Commands:** `swarmarchy restart waybar`, `swarmarchy refresh waybar`, `swarmarchy toggle waybar`

### Terminal

```
~/.config/foot/foot.ini
```

**Command:** `swarmarchy restart terminal`

### Other Configs

| App | Location |
|-----|----------|
| btop | `~/.config/btop/btop.conf` |
| fastfetch | `~/.config/fastfetch/config.jsonc` |
| lazygit | `~/.config/lazygit/config.yml` |
| starship | `~/.config/starship.toml` |
| git | `~/.config/git/config` |
| walker | `~/.config/walker/config.toml` |

## Safe Customization Patterns

### Pattern 1: Edit User Config Directly

For simple changes, edit files in `~/.config/`:

```bash
# 1. Read current config
cat ~/.config/sway/bindings.conf

# 2. Backup before changes
cp ~/.config/sway/bindings.conf ~/.config/sway/bindings.conf.bak.$(date +%s)

# 3. Make changes with Edit tool

# 4. Apply changes
# - Sway: does NOT auto-reload — run `swaymsg reload` (validate first with `sway --validate`)
# - Waybar: MUST restart with `swarmarchy restart waybar`
# - Walker: MUST restart with `swarmarchy restart walker`
# - Terminal: MUST restart with `swarmarchy restart terminal`
```

### Pattern 2: Make a new theme

1. Create a directory under ~/.config/swarmarchy/themes.
2. See how an existing theme is done via /usr/share/swarmarchy/themes/tokyo-night.
3. Download a matching background (or several) from the internet and put them in ~/.config/swarmarchy/themes/[name-of-new-theme]
4. When done with the theme, run `swarmarchy theme set "Name of new theme"`

### Pattern 3: Use Hooks for Automation

Create scripts in `~/.config/swarmarchy/hooks/` to run automatically on events:

```bash
# Available hooks (see samples in ~/.config/swarmarchy/hooks/):
~/.config/swarmarchy/hooks/
├── theme-set        # Runs after theme change (receives theme name as $1)
├── font-set         # Runs after font change
└── post-update      # Runs after `swarmarchy update`
```

Example hook (`~/.config/swarmarchy/hooks/theme-set`):
```bash
#!/bin/bash
THEME_NAME=$1
echo "Theme changed to: $THEME_NAME"
# Add custom actions here
```

### Pattern 4: Reset to Defaults -- ALWAYS SEEK USER CONFIRMATION BEFORE RUNNING

When customizations go wrong:

```bash
# Reset specific config (creates backup automatically)
swarmarchy refresh waybar
swarmarchy refresh sway

# The refresh command:
# 1. Backs up current config with timestamp
# 2. Copies default from /usr/share/swarmarchy/config/
# 3. Restarts the component
```

## Common Tasks

### Themes

```bash
swarmarchy theme list              # Show available themes
swarmarchy theme current           # Show current theme
swarmarchy theme set <name>        # Apply theme (use "Tokyo Night" not "tokyo-night")
swarmarchy theme bg next           # Cycle wallpaper
swarmarchy theme install <url>     # Install from git repo
```

### Keybindings

Edit `~/.config/sway/bindings.conf`. Format:
```
bindsym $mod+Return exec foot
bindsym $mod+w kill
bindsym $mod+Shift+e exec swaynag -t warning -m 'Exit sway?' -B 'Yes' 'swaymsg exit'
```

View current bindings: `swarmarchy menu keybindings --print`

**When re-binding an existing key:** in Sway the last matching `bindsym` wins, so
you simply add your `bindsym` after the defaults are included — there is no
`unbind` directive (or need for one).

1. First check existing bindings: `swarmarchy menu keybindings --print`
2. Add/override with your `bindsym` below the default includes
3. Inform the user what the key was previously bound to

Example - rebinding $mod+f (bound to fullscreen by default):
```
# Override $mod+f (was: fullscreen toggle)
bindsym $mod+f exec nautilus
```

Always tell the user: "Note: $mod+F was previously bound to fullscreen; this overrides it."

### Display/Monitors

Edit `~/.config/sway/monitors.conf`. Format:
```
output eDP-1 mode 1920x1080@60Hz position 0,0 scale 1
output HDMI-A-1 mode 2560x1440@144Hz position 1920,0 scale 1
```

List outputs: `swaymsg -t get_outputs`

### Window Rules

Sway uses `for_window [criteria] command`. Criteria match on `app_id` for native
Wayland apps and `class` for XWayland apps; find them with `swaymsg -t get_tree`.
Format:
```
for_window [app_id="pavucontrol"] floating enable
for_window [title="^Picture-in-Picture$"] floating enable, sticky enable
```

Window rules go in `~/.config/sway/` (e.g. a `windows.conf` you include). Sway's
criteria syntax is stable — see `man 5 sway` for the full list.

### Fonts

```bash
swarmarchy font list               # Available fonts
swarmarchy font current            # Current font
swarmarchy font set <name>         # Change font
```

### System

```bash
swarmarchy update                  # Full system update
swarmarchy version                 # Show Swarmarchy version
swarmarchy debug --no-sudo --print # Debug info (ALWAYS use these flags)
swarmarchy system lock             # Lock screen
swarmarchy system shutdown         # Shutdown
swarmarchy system reboot           # Reboot
```

**IMPORTANT:** Always run `swarmarchy debug` with `--no-sudo --print` flags to avoid interactive sudo prompts that will hang the terminal.

## Troubleshooting

```bash
# Get debug information (ALWAYS use these flags to avoid interactive prompts)
swarmarchy debug --no-sudo --print

# Upload logs for support
swarmarchy upload log

# Reset specific config to defaults
swarmarchy refresh <app>

# Refresh specific config file
# config-file path is relative to ~/.config/
# eg. `swarmarchy refresh config swaylock/config` will refresh ~/.config/swaylock/config
swarmarchy refresh config <config-file>

# Full reinstall of configs (nuclear option)
swarmarchy reinstall
```

## Decision Framework

When user requests system changes:

1. **Is it a stock swarmarchy command?** Use it directly
2. **Is it a config edit?** Edit in `~/.config/`, never `/usr/share/swarmarchy/`
3. **Is it a theme customization?** Create a NEW custom theme directory
4. **Is it automation?** Use hooks in `~/.config/swarmarchy/hooks/`
5. **Is it a package install?** Use `swarmarchy pkg add <pkgs...>` (or `swarmarchy pkg aur add <pkgs...>` for AUR-only packages)
6. **Unsure if command exists?** Run `swarmarchy commands` (or `swarmarchy <group> --help` for one group)

### Reminder Requests

When the user asks to set a reminder, use `swarmarchy reminder <minutes> [message]` directly. Convert natural language durations to minutes and title-case short reminder labels when appropriate.

```bash
swarmarchy reminder 15 "Pickup Jack"
swarmarchy reminder 60 "Check laundry"
swarmarchy reminder show
swarmarchy reminder clear
```

## Out of Scope

This skill intentionally does not cover Swarmarchy source development. Do not use this skill for:
- Editing files in `/usr/share/swarmarchy/` (`bin/`, `config/`, `default/`, `themes/`, `migrations/`, etc.)
- Creating or editing migrations
- Running `swarmarchy dev ...` commands

## Example Requests

- "Change my theme to Tokyo Night" -> `swarmarchy theme set "Tokyo Night"`
- "Add a keybinding for Super+E to open file manager" -> Check existing bindings first, then add a `bindsym` in `~/.config/sway/bindings.conf` (last binding wins)
- "Configure my external monitor" -> Edit `~/.config/sway/monitors.conf`
- "Make the window gaps smaller" -> Edit `~/.config/sway/looknfeel.conf`
- "Set up night light" -> `swarmarchy toggle nightlight`
- "Set a reminder to pickup jack in 15 minutes" -> `swarmarchy reminder 15 "Pickup Jack"`
- "Show my reminders" -> `swarmarchy reminder show`
- "Clear all reminders" -> `swarmarchy reminder clear`
- "Customize the Tokyo Night theme colors" -> Create `~/.config/swarmarchy/themes/tokyo-night-custom/` by copying from stock, then edit
- "Run a script every time I change themes" -> Create `~/.config/swarmarchy/hooks/theme-set`
- "Reset waybar to defaults" -> `swarmarchy refresh waybar`
