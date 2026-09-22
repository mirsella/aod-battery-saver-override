#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# shellcheck source=module/policy.sh
. ./module/policy.sh
STATE_DIR=$work/state

# Model the persistent SettingsProvider across command substitutions.
settings() {
    [ "$2" = global ] && [ "$3" = battery_saver_constants ]
    case "$1" in
        get) if [ -f "$work/setting" ]; then cat "$work/setting"; else printf 'null\n'; fi ;;
        put) printf '%s\n' "$4" > "$work/setting" ;;
        delete) rm -f "$work/setting" ;;
        *) return 1 ;;
    esac
}
log() { :; }
expect() {
    got=$(settings get global battery_saver_constants)
    if [ "$got" != "$1" ]; then
        printf 'Expected <%s>, got <%s>\n' "$1" "$got" >&2
        exit 1
    fi
}
reset() { rm -rf "$STATE_DIR" "$work/setting"; }

# Existing policy, repeated boots/updates, and unrelated edits before restore.
settings put global battery_saver_constants 'location_mode=3,disable_aod=true,adjust_brightness_factor=0.8'
apply_policy
expect 'location_mode=3,disable_aod=false,adjust_brightness_factor=0.8'
apply_policy
settings put global battery_saver_constants 'location_mode=2,disable_aod=false,adjust_brightness_factor=0.8,new_policy=true'
restore_policy
expect 'location_mode=2,disable_aod=true,adjust_brightness_factor=0.8,new_policy=true'

# A previously missing setting must be deleted again.
reset
apply_policy
expect 'disable_aod=false'
restore_policy
expect null

# An explicitly empty setting is distinct from a missing setting.
reset
settings put global battery_saver_constants ''
apply_policy
restore_policy
expect ''

# Absent AOD entry and a new unrelated setting must survive restoration.
reset
settings put global battery_saver_constants 'location_mode=3'
apply_policy
settings put global battery_saver_constants 'location_mode=2,disable_aod=false,soundtrigger_mode=1'
restore_policy
expect 'location_mode=2,soundtrigger_mode=1'

# An original false value remains false on restore.
reset
settings put global battery_saver_constants 'disable_aod=false'
apply_policy
restore_policy
expect 'disable_aod=false'

# Do not overwrite an independent writer of the AOD policy.
settings put global battery_saver_constants 'disable_aod=true,location_mode=1'
restore_policy
expect 'disable_aod=true,location_mode=1'

# Duplicate keys follow Android's last-wins behavior, with whitespace retained.
reset
settings put global battery_saver_constants 'disable_aod=false, location_mode=3, disable_aod=true'
apply_policy
expect 'disable_aod=false, location_mode=3'
restore_policy
expect ' disable_aod=true, location_mode=3'

# A failed write must not report success or lose the original policy.
reset
settings put global battery_saver_constants 'disable_aod=true'
settings() {
    case "$1" in
        get) cat "$work/setting" ;;
        put) return 1 ;;
        *) return 1 ;;
    esac
}
if apply_policy; then
    printf 'Failed settings write was accepted\n' >&2
    exit 1
fi
[ "$(cat "$STATE_DIR/original")" = 'disable_aod=true' ]
printf 'Policy tests passed.\n'
