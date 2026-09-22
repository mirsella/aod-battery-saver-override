#!/system/bin/sh
set -eu
MODDIR=${0%/*}
# Load functions before the manager removes the module directory.
# shellcheck source=module/policy.sh
. "$MODDIR/policy.sh"
if [ "$(getprop sys.boot_completed)" = 1 ]; then
    restore_and_clean
else
    # Uninstall can run before SettingsProvider exists. Never block boot.
    (
        wait_for_boot && restore_and_clean
    ) </dev/null >/dev/null 2>&1 &
fi
