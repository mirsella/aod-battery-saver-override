#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
STATE_DIR=$work/state
# shellcheck source=module/policy.sh
. ./module/policy.sh

# Model the persistent SettingsProvider across command substitutions.
fail_put=
fail_config_put=
fail_override=
settings() {
    case "$1" in
        get) if [ -f "$work/setting" ]; then cat "$work/setting"; else printf 'null\n'; fi ;;
        put) [ -z "$fail_put" ] || return 1
            printf '%s\n' "$4" > "$work/setting" ;;
        delete) rm -f "$work/setting" ;;
        *) return 1 ;;
    esac
}
device_config() {
    case "$1" in
        get) if [ -f "$work/override" ]; then cat "$work/override"
            elif [ -f "$work/config" ]; then cat "$work/config"
            else printf 'null\n'; fi ;;
        put) [ -z "$fail_config_put" ] || return 1
            printf '%s\n' "$4" > "$work/config"
            device_config get battery_saver disable_aod > "$work/listener_value" ;;
        delete) [ -f "$work/config" ] || return 1
            rm "$work/config"
            device_config get battery_saver disable_aod > "$work/listener_value" ;;
        list_local_overrides) if [ -f "$work/override" ]; then
                printf 'battery_saver/disable_aod=%s\n' "$(cat "$work/override")"
            else printf 'none\n'; fi ;;
        override) [ -z "$fail_override" ] || return 1
            printf '%s\n' "$4" > "$work/override" ;;
        clear_override) rm -f "$work/override" ;;
        *) return 1 ;;
    esac
}
log() { :; }

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

expect() {
    got=$(settings get global battery_saver_constants)
    [ "$got" = "$1" ] || fail "Expected <$1>, got <$got>"
}

expect_config() {
    got=$(device_config get battery_saver disable_aod)
    [ "$got" = "$1" ] || fail "Expected DeviceConfig <$1>, got <$got>"
}

expect_raw_config() {
    got=$(read_raw_config)
    [ "$got" = "$1" ] || fail "Expected raw DeviceConfig <$1>, got <$got>"
}

expect_override() {
    got=$(read_override)
    [ "$got" = "$1" ] || fail "Expected override <$1>, got <$got>"
}

reset() { rm -rf "$STATE_DIR" "$work/setting" "$work/config" "$work/override" "$work/listener_value"; }

# Full cycle: original setting, expected after apply,
# setting present before restore, expected after restore.
roundtrip() {
    reset
    [ "$1" = null ] || settings put global battery_saver_constants "$1"
    apply_policy >/dev/null
    expect "$2"
    expect_override false
    expect_raw_config false
    settings put global battery_saver_constants "$3"
    restore_policy >/dev/null
    restore_device_config >/dev/null
    expect "$4"
    expect_override null
    expect_raw_config null
}

# Existing policy, with an unrelated edit before restore.
roundtrip 'location_mode=3,disable_aod=true,adjust_brightness_factor=0.8' \
    'location_mode=3,disable_aod=false,adjust_brightness_factor=0.8' \
    'location_mode=2,disable_aod=false,adjust_brightness_factor=0.8,new_policy=true' \
    'location_mode=2,disable_aod=true,adjust_brightness_factor=0.8,new_policy=true'

# A previously missing setting must be deleted again.
roundtrip null 'disable_aod=false' 'disable_aod=false' null

# An explicitly empty setting is distinct from a missing setting.
roundtrip '' 'disable_aod=false' 'disable_aod=false' ''

# Absent AOD entry and a new unrelated setting must survive restoration.
roundtrip 'location_mode=3' \
    'location_mode=3,disable_aod=false' \
    'location_mode=2,disable_aod=false,soundtrigger_mode=1' \
    'location_mode=2,soundtrigger_mode=1'

# An original false value remains false on restore.
roundtrip 'disable_aod=false' 'disable_aod=false' 'disable_aod=false' 'disable_aod=false'

# Duplicate keys follow Android's last-wins behavior; restoration is normalized.
roundtrip 'disable_aod=false, location_mode=3, disable_aod=true' \
    'disable_aod=false, location_mode=3' \
    'disable_aod=false, location_mode=3' \
    'disable_aod=true, location_mode=3'

# Repeated boots keep the first snapshot.
reset
settings put global battery_saver_constants 'disable_aod=true,location_mode=3'
apply_policy >/dev/null
apply_policy >/dev/null
expect 'disable_aod=false,location_mode=3'
expect_override false
expect_raw_config false
restore_policy >/dev/null
restore_device_config >/dev/null
expect 'disable_aod=true,location_mode=3'
expect_override null
expect_raw_config null

# Restoring twice is a no-op the second time.
restore_policy >/dev/null
restore_device_config >/dev/null
expect 'disable_aod=true,location_mode=3'

# Do not overwrite an independent writer of the AOD policy.
settings put global battery_saver_constants 'disable_aod=true,location_mode=1'
restore_policy >/dev/null
expect 'disable_aod=true,location_mode=1'

# A server-provided DeviceConfig value survives install and restore.
reset
device_config put battery_saver disable_aod true
apply_policy >/dev/null
expect_config false
expect_override false
expect_raw_config false
restore_device_config >/dev/null
expect_config true
expect_override null
expect_raw_config true

# A server reset cannot remove a sticky override.
reset
apply_policy >/dev/null
device_config put battery_saver disable_aod true
expect_config false
device_config delete battery_saver disable_aod
expect_config false
restore_device_config >/dev/null
expect_config null
[ "$(cat "$work/listener_value")" = null ] || fail 'Restore left the active policy cached after a server reset'

# A server change to the ordinary value remains in place after restoration.
reset
apply_policy >/dev/null
device_config put battery_saver disable_aod true
restore_device_config >/dev/null
expect_override null
expect_raw_config true
[ "$(cat "$work/listener_value")" = true ] || fail 'Restore did not apply the independent DeviceConfig value'

# Clearing an override alone does not notify Android's Battery Saver listener.
# The underlying value must be restored afterward to update the active policy.
reset
apply_policy >/dev/null
[ "$(cat "$work/listener_value")" = false ] || fail 'Apply did not refresh the policy listener'
restore_device_config >/dev/null
[ "$(cat "$work/listener_value")" = null ] || fail 'Restore did not refresh the policy listener'

# A preexisting local override is restored, not removed.
reset
device_config put battery_saver disable_aod true
device_config override battery_saver disable_aod true
apply_policy >/dev/null
expect_override false
expect_raw_config false
restore_device_config >/dev/null
expect_override true
expect_raw_config true

# A restored override also refreshes the policy when the underlying value was already false.
reset
device_config put battery_saver disable_aod false
device_config override battery_saver disable_aod true
apply_policy >/dev/null
restore_device_config >/dev/null
expect_override true
expect_raw_config false
[ "$(cat "$work/listener_value")" = true ] || fail 'Restore left the preexisting override out of the active policy'

# A later local override by another writer is left alone.
reset
apply_policy >/dev/null
device_config override battery_saver disable_aod true
restore_device_config >/dev/null
expect_override true
expect_raw_config null

# Uninstall helper restores, then drops the backup.
reset
settings put global battery_saver_constants 'disable_aod=true'
apply_policy >/dev/null
restore_and_clean >/dev/null
expect 'disable_aod=true'
expect_override null
expect_raw_config null
[ ! -e "$STATE_DIR" ] || fail "Backup directory was not removed"

# A failed write must not report success or lose the original policy.
reset
settings put global battery_saver_constants 'disable_aod=true'
fail_put=1
if apply_policy >/dev/null; then
    fail 'Failed settings write was accepted'
fi
fail_put=
[ "$(cat "$STATE_DIR/original")" = 'disable_aod=true' ]

# A failed DeviceConfig override retains both original values for recovery.
reset
settings put global battery_saver_constants 'disable_aod=true'
fail_override=1
if apply_policy >/dev/null; then
    fail 'Failed DeviceConfig override was accepted'
fi
fail_override=
[ "$(cat "$STATE_DIR/original")" = 'disable_aod=true' ]
[ "$(cat "$STATE_DIR/device_config_override_original")" = null ]
expect_override null

# A failed ordinary DeviceConfig write retains both original values.
reset
settings put global battery_saver_constants 'disable_aod=true'
fail_config_put=1
if apply_policy >/dev/null; then
    fail 'Failed DeviceConfig value write was accepted'
fi
fail_config_put=
[ "$(cat "$STATE_DIR/device_config_original")" = null ]
[ "$(cat "$STATE_DIR/device_config_override_original")" = null ]
restore_and_clean >/dev/null
expect_override null
expect_raw_config null

# An older 0.2.0 backup gains DeviceConfig snapshots on upgrade.
reset
mkdir -p "$STATE_DIR"
printf 'disable_aod=true\n' > "$STATE_DIR/original"
settings put global battery_saver_constants 'disable_aod=false'
apply_policy >/dev/null
[ "$(cat "$STATE_DIR/device_config_override_original")" = null ]
[ "$(cat "$STATE_DIR/device_config_original")" = null ]
restore_and_clean >/dev/null
expect 'disable_aod=true'
expect_override null
expect_raw_config null
printf 'Policy tests passed.\n'
