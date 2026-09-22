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
settings() {
    case "$1" in
        get) if [ -f "$work/setting" ]; then cat "$work/setting"; else printf 'null\n'; fi ;;
        put) [ -z "$fail_put" ] || return 1
            printf '%s\n' "$4" > "$work/setting" ;;
        delete) rm -f "$work/setting" ;;
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

reset() { rm -rf "$STATE_DIR" "$work/setting"; }

# Full cycle: original setting, expected after apply,
# setting present before restore, expected after restore.
roundtrip() {
    reset
    [ "$1" = null ] || settings put global battery_saver_constants "$1"
    apply_policy >/dev/null
    expect "$2"
    settings put global battery_saver_constants "$3"
    restore_policy >/dev/null
    expect "$4"
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
restore_policy >/dev/null
expect 'disable_aod=true,location_mode=3'

# Restoring twice is a no-op the second time.
restore_policy >/dev/null
expect 'disable_aod=true,location_mode=3'

# Do not overwrite an independent writer of the AOD policy.
settings put global battery_saver_constants 'disable_aod=true,location_mode=1'
restore_policy >/dev/null
expect 'disable_aod=true,location_mode=1'

# Uninstall helper restores, then drops the backup.
reset
settings put global battery_saver_constants 'disable_aod=true'
apply_policy >/dev/null
restore_and_clean >/dev/null
expect 'disable_aod=true'
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
printf 'Policy tests passed.\n'
