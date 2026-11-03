# Swarmarchy Manual

How to use Swarmarchy day to day, and which file to edit when you want to change something.
Open this any time from **Super+Space → Learn → Swarmarchy**. It is installed at
`/usr/share/swarmarchy/MANUAL.md` (this page is generated from it), so it works offline.

## Contents

- [Getting around](#getting-around)
- [Windows](#windows)
- [Workspaces and monitors](#workspaces-and-monitors)
- [Everyday tools](#everyday-tools)
- [Customizing](#customizing)
- [After an install](#after-an-install)

## Getting around

| Keys | What it does |
|---|---|
| **Super+Space** | The Swarmarchy menu. Type to search apps *and* every menu entry at once. |
| **Super+M** | Every keybinding, searchable. |
| **Super+Escape** | System menu: lock, suspend, restart, shut down. |
| **Super+Return** | Terminal, opened in the current terminal's folder. |
| **Super+Alt+Return** | Browser (add Shift for a private window). |
| **Super+E** | File manager (yazi). |
| **Super+Ctrl+V** | Clipboard history. |

### Mac-style shortcuts

Super works like the Mac's Command key: **Super+C / V / X** copy, paste and cut, and
**Super+T, W, Z, Y, A, S, F, R, N, P, L** send the usual Ctrl shortcut (new tab, close tab, undo,
redo, select all, save, find, reload, new window, print, address bar). **Super+[ / ]** go back and
forward, **Super+Shift+[ / ]** switch tabs, **Super+9** jumps to the last tab, **Super+= / − / 0**
zoom in, out and back to normal in a terminal (font size); in the browser only **Super+0** works,
so use Ctrl+= / Ctrl+− there. **Super+Left / Right** jump to the start or end of the line (add
Shift to select).

In a terminal these are skipped (except copy, paste and Home/End), so **Ctrl keeps its terminal
meaning**: Ctrl+C interrupts, Ctrl+A / Ctrl+E move along the line. Super+M hides these
shortcuts to keep the list short; they are in the "Mac-style app shortcuts" section of
`/usr/share/swarmarchy/default/sway/bindings.conf`.

### What the modifiers mean

| With Super | Meaning | Examples |
|---|---|---|
| **Super** alone | App editing (above), workspaces | Super+C, Super+1 |
| **Super+Shift** | The "move" version of a Super key | Super+Shift+3 sends the window to workspace 3 |
| **Super+Ctrl** | System and settings | menus, toggles, Wi-Fi, Bluetooth, audio, lock |
| **Super+Alt** | Window and layout control | focus, close, float, fullscreen, tabbed, scratchpad |
| **Super+Alt+Shift** | A bigger variant of the Super+Alt key | move a whole workspace, send to scratchpad |

Plain **Ctrl** is left to apps and the terminal.

## Windows

New windows **tile**: they split the screen instead of overlapping.

| Keys | What it does |
|---|---|
| **Super+Alt+H / J / K / L** | Focus the window left / down / up / right |
| **Super+Shift+H / J / K / L** | Move the window left / down / up / right |
| **Super+Alt+Q** | Close the window |
| **Super+Alt+F** | Fullscreen |
| **Super+Alt+T** | Float the window (free-moving) or tile it again |
| **Super+Alt+S** | Next window opens below instead of beside (or the other way) |
| **Super+Alt+arrows** | Resize |
| **Super + left-drag / right-drag** | Move / resize with the mouse |

**Tabbed layout** (**Super+Alt+G**) stacks the windows in the current area on top of each other with
a row of tabs, like browser tabs. Switch tabs with **Super+Alt+H / L**. Press Super+Alt+G
again to go back to side by side.

**Scratchpad**: a hidden floating layer for windows you want now and then (music, notes).
**Super+Alt+Shift+M** sends the window there, **Super+Alt+M** shows or hides it.

## Workspaces and monitors

| Keys | What it does |
|---|---|
| **Super+1 … 8** | Go to workspace 1–8 |
| **Super+Shift+1 … 8** | Send the window to that workspace |
| **Super+Tab / Super+Shift+Tab** | Next / previous workspace (or Super + scroll wheel) |
| **Super+Alt+Shift+H / J / K / L** | Move the whole workspace to another monitor |
| **Super+Alt+= / −** | Change the monitor's scaling |

**How numbering works.** Workspaces are created when you go to them and disappear when empty and
left. At startup each monitor takes the lowest free number in the order the monitors are found.
The bar always shows 1–5; higher numbers appear while they hold windows. A common habit is one
number per task (1 browser, 2 code, 3 chat).

**Monitor names.** The laptop screen is `eDP-1`; external screens are `DP-1`, `DP-2`, … To see
which is which:

```bash
swaymsg -t get_outputs | jq -r '.[] | "\(.name)  ws=\(.current_workspace)  at \(.rect.x),\(.rect.y)"'
swaymsg -t get_outputs | jq -r '.[] | select(.focused).name'   # the screen you're on
```

**Layout and pinning.** Positions, resolution and scale go in `~/.config/sway/monitors.conf`; its
comments explain how positions are worked out, with a three-screen example. To keep a workspace on
one screen, add `workspace 3 output DP-1 eDP-1` there (first connected screen in the list wins, and
the workspace moves back when that screen returns). Apply with `swaymsg reload`. Pinning applies
when a workspace is created, so one that already exists stays put. To renumber without moving
any windows, rename: `swaymsg 'rename workspace 1 to tmp; rename workspace 3 to 1; rename workspace tmp to 3'`.

**Laptop screen.** Turn it off or on from **Super+Space → Trigger → Hardware → Laptop Display**.

**Lid.** Closing the lid with an external monitor connected turns the laptop screen off; opening it
turns it back on.

## Everyday tools

### Notifications

| Keys | What it does |
|---|---|
| **Super+Ctrl+.** | Dismiss the newest (add Shift: dismiss all) |
| **Super+Ctrl+,** | Bring back the last dismissed one |
| **Super+Ctrl+Shift+,** | Click the notification's action (open the chat, the screenshot, …) |
| **Super+Ctrl+N** | Do not disturb on/off |

### Reminders

**Super+Ctrl+R** sets one (minutes, then an optional message). **Super+Ctrl+Shift+R** shows the
pending ones, **Super+Ctrl+E** picks one to cancel. From a terminal:
`swarmarchy reminder 30 "Check the oven"`.

### Capture, share, convert

| Keys | What it does |
|---|---|
| **Super+Ctrl+C** | Capture menu: screenshots and recordings |
| **Alt+Print** | Screen recording menu |
| **Super+Ctrl+X** | Copy the text from an area of the screen (OCR) |
| **Super+Ctrl+S** | Share a file, folder or clipboard (LocalSend) |
| **Super+Ctrl+T** | Transcode: convert a picture to jpg/png or a video to mp4/gif, saved next to the original and copied to the clipboard |

In the file manager (yazi): **Alt+T** transcodes the selected files, **Alt+L** sends them with
LocalSend, **Alt+E** extracts an archive, **C** compresses.

### Settings and toggles

| Keys | What it does |
|---|---|
| **Super+Ctrl+W / B / A** | Wi-Fi, Bluetooth, audio |
| **Super+Ctrl+H** | Hardware menu |
| **Super+Ctrl+O** | Toggle menu |
| **Super+Ctrl+L** | Night light |
| **Super+Ctrl+I** | Stop or allow auto-lock |
| **Super+Ctrl+M** | System monitor (btop) |
| **Super+Ctrl+Q** | Lock |
| **Super+Mute** | Switch audio output (speakers, headphones, monitor) |

Media keys work as labelled, also on the lock screen.

### Bar and launcher

- **Weather**: put one city per line in `~/.config/swarmarchy/weather-location` (e.g. `Vancouver`).
  The first is shown in the bar, hovering lists every city, clicking shows the forecasts. Delete the
  file to guess from your IP.
- **Battery**: the bar shows the percentage on machines with a battery.
- Picking an app in Super+Space that is already open **switches to it** instead of opening another.

## Customizing

### Where files live

| Location | What it is | Edit it? |
|---|---|---|
| `~/.config/<app>/…` | **Your** config. This is what runs. | Yes |
| `/usr/share/swarmarchy/default/<app>/…` | Shipped defaults. Your files `include` or copy them. | No, read-only (a deploy overwrites it) |
| `/etc/skel/.config/<app>/…` | The factory copy given to new users, and what `swarmarchy refresh` restores from. | No, read-only |

Edit `~/.config`, read `/usr/share/swarmarchy/default` to see a default, and use `swarmarchy refresh`
to reset something. Every file you can customize: `ls /etc/skel/.config/`

### What to edit

| To change… | Edit | Default to copy from |
|---|---|---|
| Keybindings | `~/.config/sway/bindings.conf` | `/usr/share/swarmarchy/default/sway/bindings.conf` |
| Monitors, resolution, workspace pinning | `~/.config/sway/monitors.conf` | `/etc/skel/.config/sway/monitors.conf` |
| Gaps, borders, opacity | `~/.config/sway/looknfeel.conf` | `/etc/skel/.config/sway/looknfeel.conf` |
| Startup apps | `~/.config/sway/autostart.conf` | `/usr/share/swarmarchy/default/sway/autostart.conf` |
| Keyboard, touchpad | `~/.config/sway/input.conf` | `/etc/skel/.config/sway/input.conf` |
| Top bar | `~/.config/waybar/config.jsonc`, `style.css` | `/etc/skel/.config/waybar/` |
| Launcher | `~/.config/walker/config.toml`, `~/.config/elephant/` | `/etc/skel/.config/walker/` |
| Terminal | `~/.config/foot/foot.ini` | `/etc/skel/.config/foot/foot.ini` |
| Lock screen | `~/.config/swaylock/config` | `/etc/skel/.config/swaylock/config` |
| Weather cities | `~/.config/swarmarchy/weather-location` | — |

### Applying changes

| You edited… | Apply with |
|---|---|
| `~/.config/sway/*` | `swaymsg reload` |
| `~/.config/waybar/*` | `swarmarchy restart waybar` |
| `~/.config/walker/*`, `~/.config/elephant/*` | `swarmarchy restart walker` |
| `~/.config/foot/foot.ini` | open a new terminal |

### Keybindings

Add or change one in `~/.config/sway/bindings.conf`. Put a `## Label` comment on the line above the
`bindsym` and it shows up in Super+M. To replace a default key, `unbindsym` it first, then bind
it, so Sway doesn't show a "duplicate binding" error bar:

```
unbindsym $mod+e
## File manager
bindsym $mod+e exec foot -e yazi ~/Documents
```

### Themes

- `swarmarchy theme list`, `swarmarchy theme set "Tokyo Night"`, or **Super+Space → Style → Theme**.
- Next wallpaper: `swarmarchy theme bg next`.
- Your own theme: copy one from `/usr/share/swarmarchy/themes/<name>/` to
  `~/.config/swarmarchy/themes/<your-name>/`, edit its `colors.toml` and app files, then
  `swarmarchy theme set "<your-name>"`.
- `~/.config/swarmarchy/current/theme/` is regenerated on every theme change: edit the theme, not
  that folder.

### Reset something you broke

Each reset saves a backup of your file first.

```bash
swarmarchy refresh --help                 # the per-app resets
swarmarchy refresh sway                   # all of ~/.config/sway
swarmarchy refresh waybar
swarmarchy refresh config --list          # every restorable file
swarmarchy refresh config foot/foot.ini   # one file, by its ~/.config path
```

### Find a command

```bash
swarmarchy                 # command groups
swarmarchy <group> --help  # commands in a group, e.g. swarmarchy refresh --help
swarmarchy commands        # every command with a one-line summary
```

## After an install

Things to do by hand, in any order.

- **OneDrive**: sign in when asked at first login; it mounts at `~/Onedrive`. To redo it later:
  `swarmarchy setup onedrive`.
- **Weather cities**: see [Bar and launcher](#bar-and-launcher).
- **SSH and GPG keys**: restore `~/.ssh` and `~/.gnupg` first; the clones below need them.
- **Neovim**: clone your config, e.g. `git clone git@github.com:<user>/<nvim-config>.git ~/.config/nvim`
- **Obsidian**: clone or copy your vault.
- **Dev tools**: `mise use -g node@latest ruby@latest`. Ruby uses prebuilt binaries
  (`[settings.ruby] compile = false`).
- **Package publishing** (only if you publish to R2): `rclone config` for a `Swarmarchy:` remote.
  The token can't create buckets, so pass `--s3-no-check-bucket` to `rclone copy`.

Your git name and email are set by the installer's prompts.
