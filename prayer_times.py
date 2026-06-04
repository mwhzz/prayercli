#!/usr/bin/env python3
"""
PrayerCLI — Prayer Time Calculator
Calculates all prayer times offline using astronomical formulas.
Method: Muslim World League (MWL) — Fajr 18°, Isha 17°
Usage: python3 prayer_times.py <lat> <lng> <utc_offset>
Output: JSON with all prayer times
"""
import sys, math, json
from datetime import date, datetime, timedelta

def calc_times(lat, lng, utc_offset, fajr_angle=18, isha_angle=17):
    today = date.today()
    y, m, d = today.year, today.month, today.day

    # Julian day
    JD = (367*y - int(7*(y+int((m+9)/12))/4)
          + int(275*m/9) + d + 1721013.5)
    D = JD - 2451545

    # Sun position
    M   = (357.529 + 0.98560028*D) % 360
    L0  = (280.459 + 0.98564736*D) % 360
    lam = (L0 + 1.915*math.sin(math.radians(M))
              + 0.020*math.sin(math.radians(2*M))) % 360
    eps  = 23.439 - 0.00000036*D
    RA   = math.degrees(math.atan2(
               math.cos(math.radians(eps))*math.sin(math.radians(lam)),
               math.cos(math.radians(lam)))) / 15 % 24
    decl = math.degrees(math.asin(
               math.sin(math.radians(eps))*math.sin(math.radians(lam))))

    # Equation of time
    EqT = L0/15 - RA
    while EqT >  12: EqT -= 24
    while EqT < -12: EqT += 24

    # Solar noon
    transit = 12 - EqT - (lng/15 - utc_offset)

    def hour_angle(angle):
        cos_H = (math.sin(math.radians(angle))
                 - math.sin(math.radians(lat))*math.sin(math.radians(decl))) \
              / (math.cos(math.radians(lat))*math.cos(math.radians(decl)))
        if abs(cos_H) > 1: return None
        return math.degrees(math.acos(cos_H)) / 15

    def fmt(t):
        if t is None: return "N/A"
        t = t % 24
        h = int(t)
        m = int(round((t % 1) * 60))
        if m >= 60: h = (h+1)%24; m -= 60
        # 12h format
        period = "AM" if h < 12 else "PM"
        h12 = h % 12 or 12
        return f"{h12:02d}:{m:02d} {period}"

    def fmt24(t):
        if t is None: return "00:00"
        t = t % 24
        h = int(t)
        m = int(round((t % 1) * 60))
        if m >= 60: h = (h+1)%24; m -= 60
        return f"{h:02d}:{m:02d}"

    # Asr — Shafi method (shadow = 1x object)
    # Hanafi method uses shadow = 2x — change 1 to 2 below if needed
    cot_asr = 1 + math.tan(math.radians(abs(lat - decl)))
    asr_angle = math.degrees(math.atan(1/cot_asr))

    H_fajr    = hour_angle(-fajr_angle)
    H_sunrise = hour_angle(-0.833)       # standard sunrise angle
    H_asr     = hour_angle(asr_angle)
    H_maghrib = hour_angle(-0.833)       # same as sunset
    H_isha    = hour_angle(-isha_angle)

    fajr    = transit - H_fajr    if H_fajr    else None
    sunrise = transit - H_sunrise if H_sunrise else None
    dhuhr   = transit + 0.0       # solar noon + small offset
    asr     = transit + H_asr     if H_asr     else None
    maghrib = transit + H_maghrib if H_maghrib else None
    isha    = transit + H_isha    if H_isha    else None

    # Tahajjud = last third of night (Isha to Fajr)
    tahajjud = None
    if fajr and isha:
        night_duration = (fajr + 24 - isha) % 24
        tahajjud = (isha + (night_duration * 2/3)) % 24

    times = {
        "date":     str(today),
        "Fajr":     fmt(fajr),
        "Sunrise":  fmt(sunrise),
        "Dhuhr":    fmt(dhuhr),
        "Asr":      fmt(asr),
        "Maghrib":  fmt(maghrib),
        "Isha":     fmt(isha),
        "Tahajjud": fmt(tahajjud),
        # 24h versions for comparisons
        "_24": {
            "Fajr":     fmt24(fajr),
            "Sunrise":  fmt24(sunrise),
            "Dhuhr":    fmt24(dhuhr),
            "Asr":      fmt24(asr),
            "Maghrib":  fmt24(maghrib),
            "Isha":     fmt24(isha),
            "Tahajjud": fmt24(tahajjud),
        }
    }
    return times

if __name__ == "__main__":
    lat = float(sys.argv[1]) if len(sys.argv) > 1 else 23.8103
    lng = float(sys.argv[2]) if len(sys.argv) > 2 else 90.4125
    utc = float(sys.argv[3]) if len(sys.argv) > 3 else 6.0
    print(json.dumps(calc_times(lat, lng, utc), indent=2))
