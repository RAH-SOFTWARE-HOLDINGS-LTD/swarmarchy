if command -v limine &>/dev/null; then
  sudo tee /etc/mkinitcpio.conf.d/swarmarchy_hooks.conf <<EOF >/dev/null
HOOKS=(base udev keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
EOF
  sudo tee /etc/mkinitcpio.conf.d/thunderbolt_module.conf <<EOF >/dev/null
MODULES+=(thunderbolt)
EOF

  # Detect boot mode
  [[ -d /sys/firmware/efi ]] && EFI=true

  # Find config location
  if [[ -f /boot/EFI/arch-limine/limine.conf ]]; then
    limine_config="/boot/EFI/arch-limine/limine.conf"
  elif [[ -f /boot/EFI/BOOT/limine.conf ]]; then
    limine_config="/boot/EFI/BOOT/limine.conf"
  elif [[ -f /boot/EFI/limine/limine.conf ]]; then
    limine_config="/boot/EFI/limine/limine.conf"
  elif [[ -f /boot/limine/limine.conf ]]; then
    limine_config="/boot/limine/limine.conf"
  elif [[ -f /boot/limine.conf ]]; then
    limine_config="/boot/limine.conf"
  else
    echo "Error: Limine config not found" >&2
    exit 1
  fi

  CMDLINE=$(grep "^[[:space:]]*cmdline:" "$limine_config" | head -1 | sed 's/^[[:space:]]*cmdline:[[:space:]]*//')

  # Every downstream consumer of root= gets it through this one value: it is
  # substituted into /etc/default/limine below, which the UKI bakes in and
  # limine-update reads, and which the ALARM fallback near the end reads back.
  # So an empty $CMDLINE yields unbootable UKIs *and* an unbootable fallback
  # entry, while every "does an entry exist" check still passes and the install
  # reports success. Derive it from the live system rather than carry on empty.
  if [[ $CMDLINE != *root=* ]]; then
    derived_uuid=$(findmnt -no UUID /)
    derived_subvol=$(findmnt -no FSROOT / | sed 's|^/||')
    if [[ -z $derived_uuid ]]; then
      echo "Error: $limine_config has no usable cmdline and / has no readable UUID" >&2
      exit 1
    fi
    CMDLINE="root=UUID=${derived_uuid} rootflags=subvol=${derived_subvol:-@} rw"
    echo "Warning: no root= in $limine_config; derived it from the live system" >&2
  fi

  # Write /etc/default/limine *before* installing limine-mkinitcpio-hook, whose
  # post-transaction deploy hook runs limine-install and reads this file. Without
  # it, ESP_PATH falls back to bootctl, which in a chroot prints a warning that
  # gets captured as the path and trips a spurious "invalid ESP" error.
  sudo cp $SWARMARCHY_PATH/default/limine/default.conf /etc/default/limine
  sudo sed -i "s|@@CMDLINE@@|$CMDLINE|g" /etc/default/limine

  # Append any drop-in kernel cmdline configs (from hardware fix scripts, etc.)
  for dropin in /etc/limine-entry-tool.d/*.conf; do
    [ -f "$dropin" ] && cat "$dropin" | sudo tee -a /etc/default/limine >/dev/null
  done

  # UKI and EFI fallback are EFI only
  if [[ -z $EFI ]]; then
    sudo sed -i '/^ENABLE_UKI=/d; /^ENABLE_LIMINE_FALLBACK=/d' /etc/default/limine
  fi

  # Remove the original config file if it's not /boot/limine.conf, so the deploy
  # hook doesn't see conflicting configs on the same ESP.
  if [[ $limine_config != "/boot/limine.conf" ]] && [[ -f $limine_config ]]; then
    sudo rm "$limine_config"
  fi

  # We overwrite the whole thing knowing the limine-update will add the entries for us
  sudo cp $SWARMARCHY_PATH/default/limine/limine.conf /boot/limine.conf

  sudo pacman -S --noconfirm --needed limine-snapper-sync limine-mkinitcpio-hook

  # Only snapshot root — /home is user data; rolling it back loses user work
  if ! sudo snapper list-configs 2>/dev/null | grep -q "root"; then
    sudo snapper -c root create-config /
  fi
  sudo cp $SWARMARCHY_PATH/default/snapper/root /etc/snapper/configs/root

  # Disable btrfs quotas — full qgroup accounting is a major performance drag
  sudo btrfs quota disable / 2>/dev/null || true

  chrootable_systemctl_enable limine-snapper-sync.service
fi

echo "Re-enabling mkinitcpio hooks..."

# Restore the specific mkinitcpio pacman hooks
if [[ -f /usr/share/libalpm/hooks/90-mkinitcpio-install.hook.disabled ]]; then
  sudo mv /usr/share/libalpm/hooks/90-mkinitcpio-install.hook.disabled /usr/share/libalpm/hooks/90-mkinitcpio-install.hook
fi

if [[ -f /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook.disabled ]]; then
  sudo mv /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook.disabled /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook
fi

echo "mkinitcpio hooks re-enabled"

# Installing limine-mkinitcpio-hook above already triggered a full UKI rebuild
# (via 80-limine-efi-deploy.hook + 90-mkinitcpio-install.hook), which writes the
# boot entries into /boot/limine.conf. Only fall back to limine-update if those
# hooks didn't run for some reason — running it unconditionally rebuilds every
# UKI a second time.
# "^/" is any menu entry: CONFIG.md says an entry is a line starting with "/".
# (The previous "^/+" was a basic regex matching a literal "/+", so it never
# matched a plain "/Name" entry.)
if ! grep -q "^/" /boot/limine.conf; then
  sudo limine-update
fi

# Fallback for Arch Linux ARM. limine-entry-tool locates kernels by reading
# /usr/lib/modules/<version>/pkgbase, which mainline Arch's kernel package ships
# and ALARM's linux-aarch64 does not. It therefore finds no kernels, writes no
# entries, and returns success -- leaving a bootloader whose menu says
# "config file contains no valid entries". limine-install also exits early here
# ("The system is not x86_64."). Write a direct kernel entry instead.
if ! grep -q "^/" /boot/limine.conf; then
  echo "No boot entries were generated; writing one directly." >&2

  root_uuid="$(findmnt -no UUID /)"
  root_subvol="$(findmnt -no FSROOT / | sed 's|^/||')"
  kernel=""
  for candidate in /boot/Image /boot/vmlinuz-linux; do
    [[ -f $candidate ]] && { kernel="${candidate#/boot/}"; break; }
  done
  initramfs=""
  for candidate in /boot/initramfs-linux.img /boot/initramfs-linux-fallback.img; do
    [[ -f $candidate ]] && { initramfs="${candidate#/boot/}"; break; }
  done

  if [[ -z $kernel || -z $initramfs || -z $root_uuid ]]; then
    echo "Error: cannot build a boot entry (kernel='$kernel' initramfs='$initramfs' root='$root_uuid')" >&2
    exit 1
  fi

  # Snapdragon boards boot via device tree, not ACPI. global_dtb applies to every
  # entry that does not set its own dtb_path, so any entries generated later
  # inherit it too.
  board_dtb="$(find /boot/dtbs -name 'x1e80100-lenovo-yoga-slim7x.dtb' 2>/dev/null | head -1)"
  if [[ -n $board_dtb ]]; then
    grep -q '^global_dtb:' /boot/limine.conf ||
      sudo sed -i "1i global_dtb: boot():/${board_dtb#/boot/}" /boot/limine.conf
  fi

  cmdline="root=UUID=${root_uuid} rootflags=subvol=${root_subvol:-@} rw"

  # /etc/default/limine carries the complete option list -- the root= this script
  # scraped out of the ISO's limine.conf, the fixed quiet/splash set from
  # default/limine/default.conf, and any /etc/limine-entry-tool.d drop-ins the
  # hardware fix scripts wrote -- so it is the better source and wins when usable.
  #
  # But root= reaches that file from exactly one place: the `cmdline:` line in the
  # ISO's limine.conf. If that scrape came back empty, the file holds only the fixed
  # options, and the entry below would name no root device. That entry is unbootable
  # yet still satisfies the `grep "^/"` checks, so the install would report success
  # on a machine that cannot start. Fall back to the computed value in that case.
  if [[ -f /etc/default/limine ]]; then
    extracted=$(sed -n 's/^KERNEL_CMDLINE\[default\]+="\(.*\)"$/\1/p' /etc/default/limine | tr '\n' ' ')
    if [[ $extracted == *root=* ]]; then
      cmdline="$extracted"
    else
      echo "Warning: /etc/default/limine names no root device; using the computed cmdline." >&2
    fi
  fi

  sudo tee -a /boot/limine.conf >/dev/null <<ENTRY

/${TARGET_OS_NAME:-Swarmarchy}
    protocol: linux
    path: boot():/${kernel}
    cmdline: ${cmdline}
    module_path: boot():/${initramfs}
ENTRY
fi

if ! grep -q "^/" /boot/limine.conf; then
  echo "Error: failed to add boot entries to /boot/limine.conf" >&2
  exit 1
fi

if [[ -n $EFI ]] && efibootmgr &>/dev/null; then
  # Remove the archinstall-created Limine entry
  while IFS= read -r bootnum; do
    sudo efibootmgr -b "$bootnum" -B >/dev/null 2>&1
  done < <(efibootmgr | grep -E "^Boot[0-9]{4}\*? Arch Linux Limine" | sed 's/^Boot\([0-9]\{4\}\).*/\1/')
fi
