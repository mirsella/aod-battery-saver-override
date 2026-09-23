#!/system/bin/sh

# STATE_DIR survives module updates and deferred uninstall; tests override it.
STATE_DIR=${STATE_DIR:-/data/adb/aod-battery-saver-override}
POLICY_KEY=battery_saver_constants
CONFIG_NAMESPACE=battery_saver
CONFIG_KEY=disable_aod

say() {
    printf '%s\n' "$*"
    /system/bin/log -t AodSaverOverride "$*" 2>/dev/null || log -t AodSaverOverride "$*" 2>/dev/null || :
}

wait_for_boot() {
    attempts=0
    until [ "$(getprop sys.boot_completed)" = 1 ]; do
        if [ "$attempts" -ge 180 ]; then
            say "Boot did not complete within six minutes; saved policy retained."
            return 1
        fi
        sleep 2
        attempts=$((attempts + 1))
    done
}

# Effective disable_aod value: true, false, or empty when absent.
# Android resolves duplicate keys with last-wins.
aod_value() {
    awk -F, '{
        for (i = 1; i <= NF; i++) {
            key = $i; sub(/=.*/, "", key); gsub(/^[ \t]+|[ \t]+$/, "", key)
            if (key == "disable_aod") {
                value = $i; sub(/^[^=]*=/, "", value); gsub(/^[ \t]+|[ \t]+$/, "", value)
            }
        }
        print value
    }'
}

# Rewrite only the AOD entry, preserving other entries and their order.
# An empty replacement removes the entry; "null" input means no stored policy.
merge_aod() {
    awk -v replacement="$1" -F, '
        function emit(entry) { result = result separator entry; separator = "," }
        $0 != "null" {
            for (i = 1; i <= NF; i++) {
                key = $i; sub(/=.*/, "", key); gsub(/^[ \t]+|[ \t]+$/, "", key)
                if (key == "disable_aod") {
                    if (!seen++ && replacement != "") emit(replacement)
                } else if ($i != "") emit($i)
            }
        }
        END {
            if (!seen && replacement != "") emit(replacement)
            print result
        }'
}

write_policy() {
    if [ "$1" = null ]; then
        settings delete global "$POLICY_KEY" >/dev/null || return 1
    else
        settings put global "$POLICY_KEY" "$1" || return 1
    fi
    actual=$(settings get global "$POLICY_KEY") || return 1
    if [ "$actual" != "$1" ]; then
        say "Battery Saver policy write did not stick; another policy writer may be active."
        return 1
    fi
}

read_override() {
    overrides=$(device_config list_local_overrides) || return 1
    for entry in $overrides; do
        case "$entry" in
            "$CONFIG_NAMESPACE/$CONFIG_KEY="*)
                printf '%s\n' "${entry#*=}"
                return 0
                ;;
        esac
    done
    printf 'null\n'
}

write_override() {
    if [ "$1" = null ]; then
        device_config clear_override "$CONFIG_NAMESPACE" "$CONFIG_KEY" || return 1
    else
        device_config override "$CONFIG_NAMESPACE" "$CONFIG_KEY" "$1" || return 1
    fi
    actual=$(read_override) || return 1
    if [ "$actual" != "$1" ]; then
        say "Battery Saver DeviceConfig override did not stick."
        return 1
    fi
}

read_raw_config() {
    active_override=$(read_override) || return 1
    if [ "$active_override" = null ]; then
        device_config get "$CONFIG_NAMESPACE" "$CONFIG_KEY"
        return
    fi
    device_config clear_override "$CONFIG_NAMESPACE" "$CONFIG_KEY" || return 1
    raw=$(device_config get "$CONFIG_NAMESPACE" "$CONFIG_KEY")
    result=$?
    device_config override "$CONFIG_NAMESPACE" "$CONFIG_KEY" "$active_override" || return 1
    [ "$result" -eq 0 ] || return 1
    printf '%s\n' "$raw"
}

write_raw_config() {
    if [ "$1" = null ]; then
        device_config delete "$CONFIG_NAMESPACE" "$CONFIG_KEY" >/dev/null || return 1
    else
        device_config put "$CONFIG_NAMESPACE" "$CONFIG_KEY" "$1" || return 1
    fi
    actual=$(read_raw_config) || return 1
    if [ "$actual" != "$1" ]; then
        say "Battery Saver DeviceConfig value did not stick."
        return 1
    fi
}

save_once() {
    [ -f "$STATE_DIR/$1" ] && return 0
    printf '%s\n' "$2" > "$STATE_DIR/$1.tmp" || return 1
    mv "$STATE_DIR/$1.tmp" "$STATE_DIR/$1"
}

apply_policy() {
    current=$(settings get global "$POLICY_KEY") || return 1
    config_override=$(read_override) || return 1
    umask 077
    mkdir -p "$STATE_DIR" || return 1
    save_once original "$current" || return 1
    save_once device_config_override_original "$config_override" || return 1
    if [ ! -f "$STATE_DIR/device_config_original" ]; then
        config=$(read_raw_config) || return 1
        save_once device_config_original "$config" || return 1
    fi
    updated=$(printf '%s\n' "$current" | merge_aod disable_aod=false) || return 1
    write_policy "$updated" || return 1
    if [ "$config_override" != false ]; then
        write_override false || return 1
    fi
    # The ordinary flag notifies BatterySaverPolicy's DeviceConfig listener.
    # The local override keeps subsequent server updates from changing it.
    write_raw_config false || return 1
    say "AOD allowed during Battery Saver."
}

restore_policy() {
    if [ ! -f "$STATE_DIR/original" ]; then
        say "No saved policy to restore."
        return 0
    fi
    original=$(cat "$STATE_DIR/original") || return 1
    current=$(settings get global "$POLICY_KEY") || return 1
    current_value=$(printf '%s\n' "$current" | aod_value) || return 1
    previous=$(printf '%s\n' "$original" | aod_value) || return 1
    if [ "$current_value" = "$previous" ]; then
        say "AOD policy already matches the saved policy."
        return 0
    fi
    if [ "$current_value" != false ]; then
        say "AOD policy changed independently; leaving it untouched."
        return 0
    fi
    case "$previous" in
        true|false) replacement="disable_aod=$previous" ;;
        *) replacement="" ;;
    esac
    restored=$(printf '%s\n' "$current" | merge_aod "$replacement") || return 1
    if [ -z "$restored" ] && [ "$original" = null ]; then
        restored=null
    fi
    write_policy "$restored" || return 1
    say "Previous AOD policy restored; other Battery Saver settings preserved."
}

restore_device_config() {
    override_restored=
    if [ -f "$STATE_DIR/device_config_override_original" ]; then
        saved_override=$(cat "$STATE_DIR/device_config_override_original") || return 1
        current_override=$(read_override) || return 1
        if [ "$current_override" = false ] && [ "$saved_override" != false ]; then
            write_override "$saved_override" || return 1
            override_restored=1
            say 'Previous Battery Saver DeviceConfig override restored.'
        elif [ "$current_override" != "$saved_override" ]; then
            say 'Battery Saver DeviceConfig override changed independently; leaving it untouched.'
        fi
    fi

    current_raw=$(read_raw_config) || return 1
    if [ -f "$STATE_DIR/device_config_original" ]; then
        saved_raw=$(cat "$STATE_DIR/device_config_original") || return 1
        if [ "$current_raw" = false ] && [ "$saved_raw" != false ]; then
            write_raw_config "$saved_raw" || return 1
            say 'Previous Battery Saver DeviceConfig value restored.'
            return 0
        fi
        if [ "$current_raw" != "$saved_raw" ]; then
            say 'Battery Saver DeviceConfig value changed independently; leaving it untouched.'
        fi
    fi

    # Changing the override alone does not notify BatterySaverPolicy.
    if [ -n "$override_restored" ]; then
        if [ "$current_raw" = null ]; then
            write_raw_config false || return 1
        fi
        write_raw_config "$current_raw" || return 1
    fi
}

restore_and_clean() {
    restore_policy && restore_device_config && rm -rf "$STATE_DIR"
}
