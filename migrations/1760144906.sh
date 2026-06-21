echo "Change swarmarchy-screenrecord to use gpu-screen-recorder"
swarmarchy-pkg-drop wf-recorder wl-screenrec

# Add slurp in case it hadn't been picked up from an old migration
swarmarchy-pkg-add slurp gpu-screen-recorder
