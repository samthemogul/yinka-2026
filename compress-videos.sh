#!/usr/bin/env bash
# ============================================================
#  compress-videos.sh
#  Batch compress all .mp4 files in the current directory.
#
#  Usage:
#    chmod +x compress-videos.sh
#    ./compress-videos.sh              # compress current dir
#    ./compress-videos.sh /path/to/dir # compress specific dir
#
#  Output: ./compressed/   (originals are NEVER touched)
# ============================================================

# ── Config ──────────────────────────────────────────────────
CRF=28          # Quality: 18 (best) → 35 (smallest). 28 = web sweet spot.
PRESET="fast"   # ultrafast / fast / medium / slow
AUDIO_BR="128k" # fine for voice + music
# ────────────────────────────────────────────────────────────

TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
OUTPUT_DIR="$TARGET_DIR/compressed"

# ── Check FFmpeg ─────────────────────────────────────────────
if ! command -v ffmpeg > /dev/null 2>&1; then
  echo ""
  echo "  ✗  FFmpeg not found. Install it first:"
  echo "     macOS:   brew install ffmpeg"
  echo "     Ubuntu:  sudo apt install ffmpeg"
  echo "     Windows: https://ffmpeg.org/download.html"
  echo ""
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# ── Portable file size helper ────────────────────────────────
filesize() {
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo 0
}

# ── Portable human-readable size ────────────────────────────
human() {
  local bytes=$1
  if   [ "$bytes" -ge 1073741824 ]; then printf "%.1f GB" "$(echo "$bytes 1073741824" | awk '{printf "%.1f", $1/$2}')";
  elif [ "$bytes" -ge 1048576 ];    then printf "%.1f MB" "$(echo "$bytes 1048576"    | awk '{printf "%.1f", $1/$2}')";
  elif [ "$bytes" -ge 1024 ];       then printf "%.1f KB" "$(echo "$bytes 1024"       | awk '{printf "%.1f", $1/$2}')";
  else printf "%d B" "$bytes"; fi
}

# ── Collect mp4 files (sh-compatible, no mapfile) ───────────
PASS=0
FAIL=0
TOTAL_BEFORE=0
TOTAL_AFTER=0
COUNT=0

# Count first
for f in "$TARGET_DIR"/*.mp4 "$TARGET_DIR"/*.MP4; do
  [ -f "$f" ] && COUNT=$((COUNT + 1))
done

if [ "$COUNT" -eq 0 ]; then
  echo "No .mp4 files found in $TARGET_DIR"
  exit 0
fi

echo ""
echo "  ┌──────────────────────────────────────────────────┐"
echo "  │  🎬  Video Compression  —  $(date '+%H:%M:%S')               │"
echo "  │  CRF=$CRF  Preset=$PRESET  Audio=$AUDIO_BR                 │"
echo "  │  Found $COUNT file(s) in:                              │"
echo "  │  $TARGET_DIR"
echo "  └──────────────────────────────────────────────────┘"
echo ""

for INPUT in "$TARGET_DIR"/*.mp4 "$TARGET_DIR"/*.MP4; do
  [ -f "$INPUT" ] || continue

  FILENAME=$(basename "$INPUT")
  OUTPUT="$OUTPUT_DIR/$FILENAME"

  SIZE_BEFORE=$(filesize "$INPUT")
  TOTAL_BEFORE=$((TOTAL_BEFORE + SIZE_BEFORE))

  echo "  ▶  $FILENAME  ($(human $SIZE_BEFORE))"

  if ffmpeg -i "$INPUT" \
      -vcodec libx264 \
      -crf $CRF \
      -preset $PRESET \
      -acodec aac \
      -b:a $AUDIO_BR \
      -movflags +faststart \
      -y \
      "$OUTPUT" \
      -loglevel error 2>&1; then

    SIZE_AFTER=$(filesize "$OUTPUT")
    TOTAL_AFTER=$((TOTAL_AFTER + SIZE_AFTER))
    REDUCTION=$(awk "BEGIN {printf \"%.0f\", (1 - $SIZE_AFTER / $SIZE_BEFORE) * 100}")

    echo "     ✓  $(human $SIZE_AFTER)  (↓${REDUCTION}% smaller)"
    PASS=$((PASS + 1))
  else
    echo "     ✗  FAILED — skipping"
    FAIL=$((FAIL + 1))
  fi
  echo ""
done

# ── Summary ──────────────────────────────────────────────────
TOTAL_SAVED=$((TOTAL_BEFORE - TOTAL_AFTER))
TOTAL_REDUCTION=$(awk "BEGIN {printf \"%.0f\", (1 - $TOTAL_AFTER / $TOTAL_BEFORE) * 100}")

echo "  ─────────────────────────────────────────────────────"
echo "  ✅  $PASS compressed     ✗  $FAIL failed"
echo "  Before : $(human $TOTAL_BEFORE)"
echo "  After  : $(human $TOTAL_AFTER)"
echo "  Saved  : $(human $TOTAL_SAVED)  (${TOTAL_REDUCTION}% total reduction)"
echo ""
echo "  Compressed files → $OUTPUT_DIR"
echo ""
echo "  ⚠  Test the compressed files before replacing originals."
echo "     When ready, move them up one level and re-deploy."
echo ""