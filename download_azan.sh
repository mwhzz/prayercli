#!/bin/bash
# ============================================================
#  PrayerCLI — Azan Audio Downloader
#  Downloads real azan audio using yt-dlp (runs once)
# ============================================================

AUDIO_DIR="/usr/local/lib/prayercli/audio"
mkdir -p "$AUDIO_DIR"

# Makkah azan URLs (fallback chain)
AZAN_URLS=(
    "https://www.youtube.com/watch?v=AepBBnvBk2s"   # Makkah Fajr azan
    "https://www.youtube.com/watch?v=l7eGNYGoBX0"   # Makkah azan
    "https://www.youtube.com/watch?v=vxTScEeoMdg"   # Madina azan
)

FAJR_URLS=(
    "https://www.youtube.com/watch?v=yCi0aMEKEgg"   # Fajr specific (has Assalatu khayrun minan nawm)
    "https://www.youtube.com/watch?v=AepBBnvBk2s"
)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# Install yt-dlp if missing
if ! command -v yt-dlp &>/dev/null; then
    echo -e "${YELLOW}Installing yt-dlp...${NC}"
    curl -fsSL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
        -o /usr/local/bin/yt-dlp
    chmod +x /usr/local/bin/yt-dlp
fi

# Install ffmpeg if missing (needed for audio conversion)
if ! command -v ffmpeg &>/dev/null; then
    echo -e "${YELLOW}Installing ffmpeg...${NC}"
    apt-get install -y -qq ffmpeg 2>/dev/null
fi

download_azan() {
    local name="$1" output="$2"
    shift 2
    local urls=("$@")

    if [ -f "$output" ]; then
        echo -e "  ${GREEN}✓${NC} $name already downloaded"
        return 0
    fi

    echo -e "  Downloading $name..."
    for url in "${urls[@]}"; do
        yt-dlp \
            --extract-audio \
            --audio-format mp3 \
            --audio-quality 128K \
            --output "${output%.mp3}.%(ext)s" \
            --no-playlist \
            --quiet \
            "$url" 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} $name downloaded" && return 0
    done

    # All URLs failed — use a generated beep fallback
    echo -e "  ${YELLOW}⚠${NC} Download failed for $name — using beep fallback"
    python3 -c "
import wave, struct, math
# Generate a simple adhan-like tone sequence
sample_rate = 44100
output = '$output'
with wave.open(output.replace('.mp3','.wav'), 'w') as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(sample_rate)
    # Simple rising tone
    for freq, dur in [(440,0.5),(494,0.5),(523,1.0),(440,0.5),(392,1.5)]:
        for i in range(int(sample_rate*dur)):
            val = int(32767 * 0.5 * math.sin(2*math.pi*freq*i/sample_rate))
            f.writeframes(struct.pack('<h', val))
" 2>/dev/null
    return 1
}

echo "Downloading azan audio files..."
download_azan "Regular Azan" "$AUDIO_DIR/azan.mp3" "${AZAN_URLS[@]}"
download_azan "Fajr Azan"    "$AUDIO_DIR/azan_fajr.mp3" "${FAJR_URLS[@]}"

echo ""
echo -e "${GREEN}Audio ready in $AUDIO_DIR${NC}"
ls -lh "$AUDIO_DIR/" 2>/dev/null
