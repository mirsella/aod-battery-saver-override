#!/system/bin/sh

# STATE_DIR survives module updates and deferred uninstall; tests override it.
STATE_DIR=${STATE_DIR:-/data/adb/aod-battery-saver-override}
POLICY_KEY=battery_saver_constants

say() {
    printf '%s\n' "$*"
    log -t AodSaverOverride "$*" || :
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

apply_policy() {
    current=$(settings get global "$POLICY_KEY") || return 1
    umask 077
    mkdir -p "$STATE_DIR" || return 1
    if [ ! -f "$STATE_DIR/original" ]; then
        printf '%s\n' "$current" > "$STATE_DIR/original.tmp" || return 1
        mv "$STATE_DIR/original.tmp" "$STATE_DIR/original" || return 1
    fi
    updated=$(printf '%s\n' "$current" | merge_aod disable_aod=false) || return 1
    write_policy "$updated" || return 1
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

restore_and_clean() {
    restore_policy && rm -rf "$STATE_DIR"
}
