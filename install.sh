#!/bin/bash
# ============================================================
#  PrayerCLI — Installer
#  Usage: curl -fsSL https://raw.githubusercontent.com/mwhzz/prayercli/main/install.sh | sudo bash
#  Or:    git clone ... && sudo bash install.sh
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

REPO_RAW="https://raw.githubusercontent.com/mwhzz/prayercli/main"
VERSION="1.0.0"

banner() {
cat << 'BANNER'

  ██████╗ ██████╗  █████╗ ██╗   ██╗███████╗██████╗
  ██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝██╔════╝██╔══██╗
  ██████╔╝██████╔╝███████║ ╚████╔╝ █████╗  ██████╔╝
  ██╔═══╝ ██╔══██╗██╔══██║  ╚██╔╝  ██╔══╝  ██╔══██╗
  ██║     ██║  ██║██║  ██║   ██║   ███████╗██║  ██║
  ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
  CLI — Pray on time. No excuses.

BANNER
}

step() { echo -e "\n${CYAN}▸ $1${NC}"; }
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
die()  { echo -e "\n${RED}✗ $1${NC}\n"; exit 1; }

banner
echo -e "${BOLD}PrayerCLI v${VERSION}${NC}"
echo "────────────────────────────────────"

[ "$EUID" -ne 0 ] && die "Run as root: sudo bash install.sh"
command -v apt-get &>/dev/null || die "Ubuntu/Debian required."

# ── Setup ────────────────────────────────────────────────────
step "Setup"

DETECTED_TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "Unknown")
UTC_OFFSET=$(python3 -c "
import time
offset = -time.timezone if time.daylight == 0 else -time.altzone
print(int(offset / 3600))
" 2>/dev/null || echo "6")

LAT="23.8103"; LNG="90.4125"; LOCK_MINS="30"

echo -e "\n  Timezone: ${YELLOW}${DETECTED_TZ}${NC} (UTC+${UTC_OFFSET})"
echo ""

if [ -t 0 ]; then
    read -rp "  Latitude  [Enter for Dhaka 23.8103]: " _L
    read -rp "  Longitude [Enter for Dhaka 90.4125]: " _G
    read -rp "  Prayer lock duration in minutes [Enter for 30]: " _M
    [ -n "$_L" ] && LAT="$_L"
    [ -n "$_G" ] && LNG="$_G"
    [ -n "$_M" ] && LOCK_MINS="$_M"
else
    warn "Non-interactive — using defaults. Edit: sudo nano /etc/prayercli/config.conf"
fi

ok "Location: ${LAT}, ${LNG}"
ok "UTC offset: ${UTC_OFFSET}"
ok "Prayer lock: ${LOCK_MINS} minutes"

# ── Dependencies ──────────────────────────────────────────────
step "Installing dependencies"
apt-get update -qq 2>/dev/null
PKGS=()
command -v python3     &>/dev/null || PKGS+=("python3")
command -v xinput      &>/dev/null || PKGS+=("xinput")
command -v notify-send &>/dev/null || PKGS+=("libnotify-bin")
command -v zenity      &>/dev/null || PKGS+=("zenity")
command -v paplay      &>/dev/null || PKGS+=("pulseaudio-utils")
command -v ffmpeg      &>/dev/null || PKGS+=("ffmpeg")

if [ ${#PKGS[@]} -gt 0 ]; then
    apt-get install -y -qq "${PKGS[@]}"
    ok "Installed: ${PKGS[*]}"
else
    ok "All dependencies present"
fi

# ── Directories ───────────────────────────────────────────────
step "Creating directories"
mkdir -p /usr/local/lib/prayercli/audio
mkdir -p /etc/prayercli
mkdir -p /var/log/prayercli
mkdir -p /var/lib/prayercli
ok "Directories created"

# ── Install files ─────────────────────────────────────────────
step "Installing files"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo '')"

dl() {
    local src="$1" dst="$2"
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$src" ]; then
        cp "$SCRIPT_DIR/$src" "$dst"
    else
        curl -fsSL "${REPO_RAW}/${src}" -o "$dst" || die "Failed: $src"
    fi
    ok "$(basename $dst)"
}

dl "bin/prayercli.sh"           /usr/local/lib/prayercli/prayercli.sh
dl "lib/prayer_times.py"        /usr/local/lib/prayercli/prayer_times.py
dl "lib/input_control.sh"       /usr/local/lib/prayercli/input_control.sh
dl "lib/prayer_screen.sh"       /usr/local/lib/prayercli/prayer_screen.sh
dl "lib/download_azan.sh"       /usr/local/lib/prayercli/download_azan.sh
dl "systemd/prayercli.service"  /etc/systemd/system/prayercli.service

# ── Config ────────────────────────────────────────────────────
step "Writing config"
cat > /etc/prayercli/config.conf << CONF
# PrayerCLI config — edit freely
# Apply: sudo systemctl restart prayercli

LATITUDE=${LAT}
LONGITUDE=${LNG}
UTC_OFFSET=${UTC_OFFSET}
PRAYER_LOCK_MINUTES=${LOCK_MINS}
CONF
ok "Config → /etc/prayercli/config.conf"

# ── Permissions ───────────────────────────────────────────────
step "Setting permissions"
chmod +x /usr/local/lib/prayercli/prayercli.sh
chmod +x /usr/local/lib/prayercli/input_control.sh
chmod +x /usr/local/lib/prayercli/prayer_screen.sh
chmod +x /usr/local/lib/prayercli/download_azan.sh
chmod 644 /etc/systemd/system/prayercli.service
touch /var/log/prayercli/enforcer.log
touch /var/lib/prayercli/stats.json
chmod 666 /var/log/prayercli/enforcer.log
chmod 666 /var/lib/prayercli/stats.json
ok "Permissions set"

# ── Lock files ────────────────────────────────────────────────
step "Locking core files"
chattr +i /usr/local/lib/prayercli/prayercli.sh
chattr +i /etc/systemd/system/prayercli.service
ok "Core files locked"
warn "Config NOT locked — edit freely"

# ── Download azan audio ───────────────────────────────────────
step "Downloading azan audio"
bash /usr/local/lib/prayercli/download_azan.sh || warn "Audio download failed — will use beep fallback"

# ── Start service ─────────────────────────────────────────────
step "Starting service"
systemctl daemon-reload
systemctl enable prayercli.service
systemctl start prayercli.service
ok "prayercli.service started"

# ── Show today's times ────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✅  PrayerCLI installed!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Today's prayer times (${LAT}, ${LNG}):${NC}"
echo ""
python3 /usr/local/lib/prayercli/prayer_times.py "$LAT" "$LNG" "$UTC_OFFSET" | \
    python3 -c "
import json, sys
d = json.load(sys.stdin)
icons = {'Fajr':'🌅','Sunrise':'☀️','Dhuhr':'🕛','Asr':'🌤️','Maghrib':'🌇','Isha':'🌙','Tahajjud':'⭐'}
for p in ['Fajr','Sunrise','Dhuhr','Asr','Maghrib','Isha','Tahajjud']:
    print(f\"  {icons.get(p,'🕌')} {p:<12} {d.get(p,'N/A')}\")
"
echo ""
echo "  📋 COMMANDS:"
echo "     Status:   sudo systemctl status prayercli"
echo "     Log:      sudo tail -f /var/log/prayercli/enforcer.log"
echo "     Config:   sudo nano /etc/prayercli/config.conf"
echo "     Restart:  sudo systemctl restart prayercli"
echo ""
