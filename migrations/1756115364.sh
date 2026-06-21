echo "Replace buggy native Zoom client with webapp"

if swarmarchy-pkg-present zoom; then
  swarmarchy-pkg-drop zoom
  swarmarchy-webapp-install "Zoom" https://app.zoom.us/wc/home https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/zoom.png
fi
