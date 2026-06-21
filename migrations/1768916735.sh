echo "Fix microphone gain and audio mixing on Asus ROG laptops"

source "$SWARMARCHY_PATH/install/config/hardware/asus/fix-mic.sh"
source "$SWARMARCHY_PATH/install/config/hardware/asus/fix-audio-mixer.sh"

if swarmarchy-hw-asus-rog; then
  swarmarchy-restart-pipewire
fi
