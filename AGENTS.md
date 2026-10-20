# Style

- Two spaces for indentation, no tabs
- Use bash 5 conditionals: use `[[ ]]` for string/file tests and `(( ))` for numeric tests
- In `[[ ]]`, don't quote variables, but do quote string literals when comparing values (e.g., `[[ $branch == "dev" ]]`)
- Prefer `(( ))` over numeric operators inside `[[ ]]` (e.g., `(( count < 50 ))`, not `[[ $count -lt 50 ]]`)
- For strings/paths with spaces, quote them instead of escaping spaces with `\ ` (e.g., `"$APP_DIR/Disk Usage.desktop"`, not `$APP_DIR/Disk\ Usage.desktop`)
- Shebangs must use `#!/bin/bash` consistently (never `#!/usr/bin/env bash`)
- Scripts under `install/` may be sourced and intentionally omit shebangs

# Command Naming

All commands start with `swarmarchy-`. Prefixes indicate purpose.

The authoritative command group list lives in `bin/swarmarchy` in `GROUP_DESCRIPTIONS`. Keep `GROUP_DESCRIPTIONS` updated when adding a new command prefix.

Common prefixes include:

- `cmd-` - check if commands exist, misc utility commands
- `capture-` - screenshots, screen recordings, and other capture tools
- `pkg-` - package management helpers
- `hw-` - hardware detection (return exit codes for use in conditionals)
- `refresh-` - copy default config to user's `~/.config/`
- `restart-` - restart a component
- `launch-` - open applications
- `install-` - install optional software
- `setup-` - interactive setup wizards
- `toggle-` - toggle features on/off
- `theme-` - theme management

Other current prefixes include:

- `ac-`, `audio-`, `battery-`, `brightness-`, `config-`, `debug-`, `dev-`, `drive-`, `first-`, `font-`, `haptic-`, `hibernation-`, `hook-`, `menu-`, `migrate-`, `notification-`, `plymouth-`, `powerprofiles-`, `remove-`, `show-`, `snapshot-`, `state-`, `sudo-`, `swayosd-`, `system-`, `transcode-`, `tui-`, `tz-`, `upload-`, `webapp-`, `wifi-`, `wm-`

# Command Metadata

Commands in `bin/` can declare CLI metadata in comments near the top of the file. `bin/swarmarchy` scans the first 80 lines. Run `swarmarchy commands --check` after adding, renaming or removing a command to confirm the metadata is still valid.

Supported metadata keys:

- `# swarmarchy:summary=...` - short help text
- `# swarmarchy:group=...` - command group when it differs from the filename-derived prefix
- `# swarmarchy:name=...` - command name within the group
- `# swarmarchy:args=...` - usage arguments
- `# swarmarchy:examples=...` - examples separated with ` | `
- `# swarmarchy:alias=...` / `# swarmarchy:aliases=...` - alternate routes
- `# swarmarchy:hidden=true` - hide from default command listings
- `# swarmarchy:requires-sudo=true` - mark commands that require sudo

Prefer explicit metadata for user-facing commands. Keep routes consistent with the filename unless there is a deliberate alias or compatibility route.

Example:

```bash
# swarmarchy:summary=Take a screenshot
# swarmarchy:group=capture
# swarmarchy:args=[smart|region|windows|fullscreen] [slurp|copy]
# swarmarchy:examples=swarmarchy screenshot | swarmarchy capture screenshot region
# swarmarchy:aliases=swarmarchy screenshot
```

# Install Scripts

Install entry point (`install.sh`) uses `#!/bin/bash`. Many scripts under `install/` are sourced via `run_logged` and intentionally do not have shebangs.

Install stage files follow this pattern:

- `install/*/all.sh` lists scripts in execution order
- leaf scripts are sourced by `run_logged $SWARMARCHY_INSTALL/path/to/script.sh`
- avoid `exit` in sourced install scripts unless intentionally aborting the install
- use `$SWARMARCHY_INSTALL` and `$SWARMARCHY_PATH` instead of hard-coded Swarmarchy paths
- keep hardware-specific logic under `install/config/hardware/`
- prefer helper commands for package and command checks where available

Raw `command -v`, `pacman`, and `pacman-key` are acceptable in bootstrap/preflight/package-helper contexts where the helper commands may not be available yet or where direct package-manager behavior is the point of the script.

# Helper Commands

Use these instead of raw shell commands:

- `swarmarchy-cmd-missing` / `swarmarchy-cmd-present` - check for commands
- `swarmarchy-pkg-missing` / `swarmarchy-pkg-present` - check for packages
- `swarmarchy-pkg-add` - install packages (handles both pacman and AUR)
- `swarmarchy-hw-match` - match the machine's DMI product name (and similar `hw-*` commands)

Exceptions are allowed for bootstrap, preflight, and package-helper scripts where the helper may not be available yet, where the helper itself is being implemented, or where direct package-manager behavior is required.

# Config Structure

- `config/` - default configs copied to `~/.config/`
- `default/themed/*.tpl` - templates with `{{ variable }}` placeholders for theme colors
- `themes/*/colors.toml` - theme color definitions (accent, background, foreground, color0-15)

# Visual Changes

When making visual changes, such as Waybar styles or desktop appearance, always take and analyze a screenshot after applying the change to verify the result. Use `swarmarchy capture screenshot fullscreen save` for fullscreen screenshots.

# Refresh Pattern

To copy a default config to user config with automatic backup:

```bash
swarmarchy-refresh-config swaylock/config
```

This copies `~/.local/share/swarmarchy/config/swaylock/config` to `~/.config/swaylock/config`.
