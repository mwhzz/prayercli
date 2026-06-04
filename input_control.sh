#!/bin/bash
# ============================================================
#  PrayerCLI — Input Disabler
#  Disables ALL keyboard and mouse input during prayer time
#  Uses xinput to disable every input device
# ============================================================

ACTION="${1:-disable}"  # disable or enable
LOG="/var/log/prayercli/enforcer.log"

log() { echo "[$(date '+%H:%M:%S')] INPUT: $1" >> "$LOG"; }

get_user()    { who | grep -E '\(:[0-9]' | awk '{print $1}' | head -1; }
get_display() { who | grep -E '\(:[0-9]' | grep -oE ':[0-9]+' | head -1; }
get_uid()     { id -u "$(get_user)" 2>/dev/null; }
get_bus()     { echo "unix:path=/run/user/$(get_uid)/bus"; }

SAVED_DEVICES="/var/lib/prayercli/disabled_devices.txt"

disable_all_input() {
    local user display
    user=$(get_user); display=$(get_display)
    [ -z "$user" ] && return

    log "Disabling all input devices"
    > "$SAVED_DEVICES"

    # Get all input device IDs
    sudo -u "$user" DISPLAY="$display" xinput list --id-only 2>/dev/null | while read -r id; do
        # Skip virtual devices and master devices
        name=$(sudo -u "$user" DISPLAY="$display" xinput list --name-only "$id" 2>/dev/null)
        echo "$id:$name" >> "$SAVED_DEVICES"
        sudo -u "$user" DISPLAY="$display" xinput disable "$id" 2>/dev/null
        log "Disabled: $id ($name)"
    done

    # Also disable via evdev as root fallback
    for dev in /dev/input/event*; do
        chmod 000 "$dev" 2>/dev/null
    done

    log "All input disabled"
}

enable_all_input() {
    local user display
    user=$(get_user); display=$(get_display)
    [ -z "$user" ] && return

    log "Re-enabling all input devices"

    # Restore via evdev first
    for dev in /dev/input/event*; do
        chmod 660 "$dev" 2>/dev/null
    done

    # Re-enable via xinput
    if [ -f "$SAVED_DEVICES" ]; then
        while IFS=: read -r id name; do
            sudo -u "$user" DISPLAY="$display" xinput enable "$id" 2>/dev/null
            log "Enabled: $id ($name)"
        done < "$SAVED_DEVICES"
        rm -f "$SAVED_DEVICES"
    else
        # Fallback: enable all
        sudo -u "$user" DISPLAY="$display" xinput list --id-only 2>/dev/null | while read -r id; do
            sudo -u "$user" DISPLAY="$display" xinput enable "$id" 2>/dev/null
        done
    fi

    log "All input restored"
}

case "$ACTION" in
    disable) disable_all_input ;;
    enable)  enable_all_input  ;;
    *)       echo "Usage: $0 [disable|enable]" ;;
esac
