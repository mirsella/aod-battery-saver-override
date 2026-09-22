#!/system/bin/sh
[ "${BOOTMODE:-false}" = true ] || abort "Install from the KernelSU or Magisk app."
for script in "$MODPATH"/*.sh; do
    set_perm "$script" 0 0 0755
done
ui_print "AOD Battery Saver Override"
ui_print "Disable/uninstall the old Xposed APK, then reboot."
ui_print "Action restores the previous AOD policy and disables this module."
