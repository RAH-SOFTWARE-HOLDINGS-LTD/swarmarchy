# Install the ouch.yazi archive-preview plugin.
#
# It is not an Arch package -- yazi has its own package manager, which clones the
# plugin into ~/.config/yazi/plugins/. config/yazi/{yazi.toml,keymap.toml} register
# the previewer and the compress binding; the `ouch` binary comes from
# swarmarchy-base.packages.
#
# Non-fatal on purpose: this reaches out to GitHub, and a network failure here must
# not take the whole install down over an archive previewer.

if ! command -v ya &>/dev/null; then
  echo "yazi is not installed; skipping the ouch.yazi plugin." >&2
  return 0 2>/dev/null || exit 0
fi

if ! ya pkg add ndtoan96/ouch; then
  echo "warning: could not install the ouch.yazi plugin; archives will not preview." >&2
  echo "         Retry later with: ya pkg add ndtoan96/ouch" >&2
fi
