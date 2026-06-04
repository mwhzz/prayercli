# 🕌 PrayerCLI

**Islamic prayer time enforcer for Ubuntu/Debian.**
Your PC locks at every azan. Keyboard and mouse disabled. No skip. 30 minutes.

![Platform](https://img.shields.io/badge/platform-Ubuntu%20%2F%20Debian-orange?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![Version](https://img.shields.io/badge/version-1.0.0-green?style=flat-square)

---

## What it does

- 🕌 **Tracks all 5 prayers + Sunrise (Ishraq) + Tahajjud**
- 🔊 **Plays real Makkah azan audio** (downloaded once via yt-dlp)
- 🔒 **30 minute hard lock** — screen locked, keyboard disabled, mouse disabled
- ⌨️ **xinput disables every input device** — no bypass
- 🔁 **Re-locks every 30 seconds** during prayer time
- 📅 **Recalculates daily** — offline, no internet needed after setup
- 💀 **Survives reboots** — systemd service, auto-starts
- 🔐 **Immutable files** — can't be deleted without conscious effort

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mwhzz/prayercli/main/install.sh | sudo bash
```

Or clone:
```bash
git clone https://github.com/mwhzz/prayercli
cd prayercli
sudo bash install.sh
```

---

## Prayer schedule (example — Dhaka, June 2026)

| Prayer | Time | Lock |
|---|---|---|
| 🌅 Fajr | 03:44 AM | 30 min hard lock |
| ☀️ Sunrise (Ishraq) | 05:11 AM | Reminder only |
| 🕛 Dhuhr | 11:57 AM | 30 min hard lock |
| 🌤️ Asr | 03:16 PM | 30 min hard lock |
| 🌇 Maghrib | 06:43 PM | 30 min hard lock |
| 🌙 Isha | 08:04 PM | 30 min hard lock |
| ⭐ Tahajjud | 01:11 AM | Reminder + azan only |

---

## Config

```bash
sudo nano /etc/prayercli/config.conf
sudo systemctl restart prayercli
```

| Setting | Default | Description |
|---|---|---|
| `LATITUDE` | 23.8103 | Your city latitude |
| `LONGITUDE` | 90.4125 | Your city longitude |
| `UTC_OFFSET` | 6 | Your timezone (Bangladesh = 6) |
| `PRAYER_LOCK_MINUTES` | 30 | Lock duration per prayer |

---

## Commands

```bash
# Check status
sudo systemctl status prayercli

# Watch live
sudo tail -f /var/log/prayercli/enforcer.log

# Edit config
sudo nano /etc/prayercli/config.conf

# Restart
sudo systemctl restart prayercli
```

---

## Works well with

**[BreakEnforcer](https://github.com/mwhzz/breakenforcer)** — forced work/break cycles.
Run both together: work 30 minutes, break 5 minutes, and pray on time.

---

## Requirements

- Ubuntu 22.04+ / Debian-based
- GNOME, KDE, or LightDM
- `xinput`, `python3`, `zenity`, `paplay` (auto-installed)
- Internet for initial azan download (offline after that)

---

## License

MIT
