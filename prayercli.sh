#!/bin/bash
# ============================================================
#  PrayerCLI — Main Daemon
#  Watches for prayer times and enforces 30min lock
#  Keyboard + mouse disabled, screen locked, azan played
# ============================================================

CONFIG="/etc/prayercli/config.conf"
LOG="/var/log/prayercli/enforcer.log"
TIMES_CACHE="/var/lib/prayercli/today_times.json"
STATS_FILE="/var/lib/prayercli/stats.json"
PRAYER_SCRIPT="/usr/local/lib/prayercli/prayer_times.py"
INPUT_CTL="/usr/local/lib/prayercli/input_control.sh"
PRAYER_SCREEN="/usr/local/lib/prayercli/prayer_screen.sh"
AUDIO_DIR="/usr/local/lib/prayercli/audio"
PID_FILE="/var/run/prayercli.pid"

echo $$ > "$PID_FILE"
source "$CONFIG"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"; }

# ── USER DETECTION ──────────────────────────────────────────
get_user()    { who | grep -E '\(:[0-9]' | awk '{print $1}' | head -1; }
get_display() { who | grep -E '\(:[0-9]' | grep -oE ':[0-9]+' | head -1; }
get_uid()     { id -u "$(get_user)" 2>/dev/null; }
get_bus()     { echo "unix:path=/run/user/$(get_uid)/bus"; }

# ── NOTIFY ───────────────────────────────────────────────────
notify() {
    local title="$1" msg="$2" urgency="${3:-normal}"
    local user display bus
    user=$(get_user); display=$(get_display); bus=$(get_bus)
    [ -z "$user" ] && return
    sudo -u "$user" DISPLAY="$display" DBUS_SESSION_BUS_ADDRESS="$bus" \
        notify-send "$title" "$msg" --urgency="$urgency" --expire-time=15000 2>/dev/null
}

# ── PLAY AZAN ────────────────────────────────────────────────
play_azan() {
    local is_fajr="${1:-false}"
    local user display bus
    user=$(get_user); display=$(get_display); bus=$(get_bus)
    [ -z "$user" ] && return

    local audio_file="$AUDIO_DIR/azan.mp3"
    [ "$is_fajr" = "true" ] && [ -f "$AUDIO_DIR/azan_fajr.mp3" ] && \
        audio_file="$AUDIO_DIR/azan_fajr.mp3"

    # Fallback to wav if mp3 failed
    [ ! -f "$audio_file" ] && audio_file="${audio_file%.mp3}.wav"

    if [ -f "$audio_file" ]; then
        sudo -u "$user" DISPLAY="$display" DBUS_SESSION_BUS_ADDRESS="$bus" \
            paplay "$audio_file" 2>/dev/null &
    else
        # Triple beep fallback
        for _ in 1 2 3; do
            ( speaker-test -t sine -f 800 -l 1 2>/dev/null ) &
            sleep 0.6
        done
    fi
}

# ── LOCK SCREEN ──────────────────────────────────────────────
lock_screen() {
    local user display bus
    user=$(get_user); display=$(get_display); bus=$(get_bus)
    [ -z "$user" ] && return
    sudo -u "$user" DISPLAY="$display" DBUS_SESSION_BUS_ADDRESS="$bus" \
        gnome-screensaver-command --lock 2>/dev/null || \
    loginctl lock-session 2>/dev/null || \
    sudo -u "$user" DISPLAY="$display" dm-tool lock 2>/dev/null || \
    sudo -u "$user" DISPLAY="$display" xset dpms force off 2>/dev/null
}

# ── SHOW PRAYER SCREEN ───────────────────────────────────────
show_prayer_screen() {
    local prayer="$1" mins="$2" is_fajr="$3"
    local user display bus
    user=$(get_user); display=$(get_display); bus=$(get_bus)
    [ -z "$user" ] && return
    sudo -u "$user" DISPLAY="$display" DBUS_SESSION_BUS_ADDRESS="$bus" \
        bash "$PRAYER_SCREEN" "$prayer" "$mins" "$is_fajr" 2>/dev/null &
}

# ── GET TODAY'S TIMES ─────────────────────────────────────────
get_times() {
    local today; today=$(date +%Y-%m-%d)
    # Refresh cache daily
    if [ ! -f "$TIMES_CACHE" ] || ! grep -q "\"date\": \"$today\"" "$TIMES_CACHE" 2>/dev/null; then
        python3 "$PRAYER_SCRIPT" "$LATITUDE" "$LONGITUDE" "$UTC_OFFSET" > "$TIMES_CACHE" 2>/dev/null
        log "Prayer times refreshed for $today"
    fi
    cat "$TIMES_CACHE"
}

# ── GET SPECIFIC PRAYER TIME (24h) ────────────────────────────
get_prayer_time() {
    local prayer="$1"
    get_times | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d['_24'].get('$prayer', '00:00'))
"
}

# ── CURRENT TIME IN MINUTES ───────────────────────────────────
now_mins() { echo $(( 10#$(date +%H) * 60 + 10#$(date +%M) )); }

time_to_mins() {
    local t="$1"  # HH:MM
    local h="${t%%:*}" m="${t##*:}"
    echo $(( 10#$h * 60 + 10#$m ))
}

# ── UPDATE STATS ─────────────────────────────────────────────
log_prayer() {
    python3 -c "
import json
from datetime import date
try:
    with open('$STATS_FILE') as f: d = json.load(f)
except: d = {}
today = str(date.today())
if d.get('date') != today:
    d = {'date': today, 'prayers': []}
d['prayers'].append({'name': '$1', 'time': '$(date +%H:%M)'})
with open('$STATS_FILE', 'w') as f: json.dump(d, f)
" 2>/dev/null
}

# ── ENFORCE PRAYER LOCK ───────────────────────────────────────
enforce_prayer() {
    local prayer="$1"
    local is_fajr="false"
    [ "$prayer" = "Fajr" ] && is_fajr="true"

    # Special handling for Sunrise (Ishraq) — no azan, just reminder
    if [ "$prayer" = "Sunrise" ]; then
        notify "☀️ Ishraq Time" "Pray 2 rakats for Ishraq — equal to Hajj & Umrah reward 🤲" normal
        log "Sunrise/Ishraq reminder sent"
        return
    fi

    # Tahajjud — reminder only, don't lock
    if [ "$prayer" = "Tahajjud" ]; then
        notify "⭐ Tahajjud Time" "Allah is in the lowest heaven now. Make dua. 🤲" normal
        play_azan "false"
        log "Tahajjud reminder sent"
        return
    fi

    log "=== $prayer time — enforcing 30min lock ==="
    log_prayer "$prayer"

    # 5-minute warning
    notify "🕌 $prayer in 5 minutes" "Save your work. Prayer time soon. 🤲" normal

    sleep $(( 4 * 60 ))  # wait 4 minutes

    # 1-minute warning + azan starts
    notify "🕌 $prayer NOW" "Allahu Akbar. Time to pray." critical
    play_azan "$is_fajr"

    sleep 60  # let azan play

    # LOCK EVERYTHING
    log "Locking screen and disabling input for $prayer"
    lock_screen
    bash "$INPUT_CTL" disable
    show_prayer_screen "$prayer" "$PRAYER_LOCK_MINUTES" "$is_fajr"

    # Hold lock — re-lock and re-disable every 30s
    LOCK_END=$(( $(date +%s) + PRAYER_LOCK_MINUTES * 60 ))
    while [ "$(date +%s)" -lt "$LOCK_END" ]; do
        sleep 30
        lock_screen 2>/dev/null
        bash "$INPUT_CTL" disable 2>/dev/null
    done

    # Unlock
    bash "$INPUT_CTL" enable
    log "$prayer lock released"
    notify "✅ $prayer Time Over" "Jazakallahu Khairan. Back to work. 💪" normal
}

# ── PRINT TODAY'S SCHEDULE ────────────────────────────────────
print_schedule() {
    local times; times=$(get_times)
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🕌 PrayerCLI — Today's Schedule"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for p in Fajr Sunrise Dhuhr Asr Maghrib Isha Tahajjud; do
        t=$(echo "$times" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('$p','N/A'))")
        printf "  %-12s %s\n" "$p" "$t"
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# ── MAIN LOOP ─────────────────────────────────────────────────
PRAYERS=("Fajr" "Sunrise" "Dhuhr" "Asr" "Maghrib" "Isha" "Tahajjud")
TRIGGERED=()  # prayers triggered today

log "============================================"
log "PrayerCLI STARTED"
log "Location: ${LATITUDE}, ${LONGITUDE} UTC+${UTC_OFFSET}"
log "Lock duration: ${PRAYER_LOCK_MINUTES} minutes"
print_schedule

while true; do
    NOW=$(now_mins)
    TODAY=$(date +%Y-%m-%d)

    # Reset triggers on new day
    if [ "${LAST_DATE:-}" != "$TODAY" ]; then
        TRIGGERED=()
        LAST_DATE="$TODAY"
        log "New day — prayer schedule refreshed"
        # Invalidate cache to recalculate
        rm -f "$TIMES_CACHE"
        print_schedule
    fi

    for prayer in "${PRAYERS[@]}"; do
        # Already triggered today?
        [[ " ${TRIGGERED[*]} " == *" $prayer "* ]] && continue

        PRAYER_TIME=$(get_prayer_time "$prayer")
        PRAYER_MINS=$(time_to_mins "$PRAYER_TIME")

        # Trigger 5 minutes before prayer time (warning is inside enforce_prayer)
        if [ "$NOW" -ge $(( PRAYER_MINS - 5 )) ] && [ "$NOW" -le $(( PRAYER_MINS + 35 )) ]; then
            TRIGGERED+=("$prayer")
            log "Triggering $prayer (scheduled: $PRAYER_TIME)"
            enforce_prayer "$prayer" &
            sleep 2  # small gap between triggers
        fi
    done

    sleep 30  # check every 30 seconds
done
