# Disable USB autosuspend to prevent peripheral disconnection issues -- hubs/KVMs
# autosuspending and dropping off the bus on idle. On the Yoga Slim 7x (X1E80100)
# such a drop takes the DP-alt link with it and wedges the Adreno GMU (silent hang).
#
# Two mechanisms, because the modprobe option ALONE is not enough: `options usbcore
# autosuspend=-1` is IGNORED when usbcore is built into the kernel (the usual case on
# aarch64), so we ALSO install a udev rule (power/control=on) that works regardless.

# 1. modprobe option -- effective only if usbcore is a loadable module.
if [[ ! -f /etc/modprobe.d/disable-usb-autosuspend.conf ]]; then
  echo "options usbcore autosuspend=-1" | sudo tee /etc/modprobe.d/disable-usb-autosuspend.conf
fi

# 2. udev rule -- the mechanism that actually works when usbcore is built-in.
if [[ ! -f /etc/udev/rules.d/50-usb-no-autosuspend.rules ]]; then
  sudo cp "$SWARMARCHY_PATH/default/udev/usb-no-autosuspend.rules" /etc/udev/rules.d/50-usb-no-autosuspend.rules
fi
