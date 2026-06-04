#!/bin/bash
# ============================================================
#  PrayerCLI — Prayer Lock Screen
#  Args: $1=prayer_name $2=lock_minutes $3=is_fajr
# ============================================================

PRAYER="${1:-Prayer}"
LOCK_MINS="${2:-30}"
IS_FAJR="${3:-false}"
LOCK_SECS=$(( LOCK_MINS * 60 ))

case "$PRAYER" in
    Fajr)     EMOJI="🌅"; MSG="Fajr time.\nThe best prayer is Fajr on Friday." ;;
    Sunrise)  EMOJI="☀️";  MSG="Ishraq time.\n2 rakats now = Hajj & Umrah reward." ;;
    Dhuhr)    EMOJI="🕛"; MSG="Dhuhr time.\nAllah loves those who are consistent." ;;
    Asr)      EMOJI="🌤️";  MSG="Asr time.\nWhoever misses Asr, it is as if he lost his family." ;;
    Maghrib)  EMOJI="🌇"; MSG="Maghrib time.\nPray before the time passes." ;;
    Isha)     EMOJI="🌙"; MSG="Isha time.\nWhoever prays Isha in congregation gets half the night." ;;
    Tahajjud) EMOJI="⭐"; MSG="Tahajjud time.\nAllah descends to the lowest heaven now.\nAsk anything." ;;
    *)        EMOJI="🕌"; MSG="Prayer time." ;;
esac

if command -v zenity &>/dev/null; then
    (
        for i in $(seq $LOCK_SECS -1 1); do
            MINS=$(( i / 60 ))
            SECS=$(( i % 60 ))
            PCT=$(( (LOCK_SECS - i) * 100 / LOCK_SECS ))
            echo "$PCT"
            echo "# ${EMOJI} ${PRAYER} — ${MINS}:$(printf '%02d' $SECS) remaining\n\n${MSG}\n\nAllahu Akbar 🤲"
            sleep 1
        done
        echo "100"
        echo "# Prayer time over. Jazakallahu Khairan."
    ) | zenity --progress \
        --title="${EMOJI} ${PRAYER} Time — ${LOCK_MINS} Minutes" \
        --text="Prayer time..." \
        --percentage=0 \
        --auto-close \
        --no-cancel \
        --width=500 \
        --height=300 2>/dev/null
else
    sleep "$LOCK_SECS"
    xmessage -center "${PRAYER} time over. Back to work." 2>/dev/null
fi
