#!/system/bin/sh
set -eu
MODDIR=${0%/*}
# shellcheck source=module/policy.sh
. "$MODDIR/policy.sh"
restore_policy
restore_device_config
touch "$MODDIR/disable"
say "Module disabled. Re-enable it in your root manager and reboot to apply again."
