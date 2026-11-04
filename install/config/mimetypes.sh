swarmarchy-refresh-applications
update-desktop-database ~/.local/share/applications

# Open directories in the file manager
xdg-mime default yazi.desktop inode/directory

# Open all images with imv
xdg-mime default imv.desktop image/png
xdg-mime default imv.desktop image/jpeg
xdg-mime default imv.desktop image/gif
xdg-mime default imv.desktop image/webp
xdg-mime default imv.desktop image/bmp
xdg-mime default imv.desktop image/tiff

# Browser-dependent handlers. brave-bin is in swarmarchy-base.packages, so this is
# normally Brave -- but guard on the desktop entry actually existing. Setting a handler
# that points at a missing .desktop leaves xdg-settings reporting a browser that cannot
# be launched, which breaks swarmarchy-launch-browser and every web app.
browser_desktop="brave-browser.desktop"
if [[ ! -f "/usr/share/applications/$browser_desktop" &&
      ! -f "$HOME/.local/share/applications/$browser_desktop" ]]; then
  browser_desktop=""
fi

if [[ -n $browser_desktop ]]; then
  # Open PDFs with Brave's built-in pdf viewer
  xdg-mime default "$browser_desktop" application/pdf

  # Use Brave as the default browser
  xdg-settings set default-web-browser "$browser_desktop"
  xdg-mime default "$browser_desktop" x-scheme-handler/http
  xdg-mime default "$browser_desktop" x-scheme-handler/https
else
  echo "No browser .desktop found; leaving the default browser and PDF handler unset." >&2
  echo "Install one with: swarmarchy install browser <brave|firefox|chrome|edge|zen>" >&2
fi

# Open video files with mpv
xdg-mime default mpv.desktop video/mp4
xdg-mime default mpv.desktop video/x-msvideo
xdg-mime default mpv.desktop video/x-matroska
xdg-mime default mpv.desktop video/x-flv
xdg-mime default mpv.desktop video/x-ms-wmv
xdg-mime default mpv.desktop video/mpeg
xdg-mime default mpv.desktop video/ogg
xdg-mime default mpv.desktop video/webm
xdg-mime default mpv.desktop video/quicktime
xdg-mime default mpv.desktop video/3gpp
xdg-mime default mpv.desktop video/3gpp2
xdg-mime default mpv.desktop video/x-ms-asf
xdg-mime default mpv.desktop video/x-ogm+ogg
xdg-mime default mpv.desktop video/x-theora+ogg
xdg-mime default mpv.desktop application/ogg

# Open text files with nvim
xdg-mime default nvim.desktop text/plain
xdg-mime default nvim.desktop text/english
xdg-mime default nvim.desktop text/x-makefile
xdg-mime default nvim.desktop text/x-c++hdr
xdg-mime default nvim.desktop text/x-c++src
xdg-mime default nvim.desktop text/x-chdr
xdg-mime default nvim.desktop text/x-csrc
xdg-mime default nvim.desktop text/x-java
xdg-mime default nvim.desktop text/x-moc
xdg-mime default nvim.desktop text/x-pascal
xdg-mime default nvim.desktop text/x-tcl
xdg-mime default nvim.desktop text/x-tex
xdg-mime default nvim.desktop application/x-shellscript
xdg-mime default nvim.desktop text/x-c
xdg-mime default nvim.desktop text/x-c++
xdg-mime default nvim.desktop application/xml
xdg-mime default nvim.desktop text/xml
