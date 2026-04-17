#!/bin/bash
# screenshot-optimizer — auto-downscale screenshots before they hit Claude
# https://github.com/sunglasses-dev/screenshot-optimizer
# MIT License.

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
set -uo pipefail

WATCH_DIR="${SCREENSHOT_OPTIMIZER_DIR:-${HOME}/Pictures/Screenshots}"
LOG="${HOME}/.screenshot-optimizer/optimizer.log"
MAX_DIM="${SCREENSHOT_OPTIMIZER_MAX_DIM:-1800}"
MARKER_XATTR="com.screenshot-optimizer.resized"

mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

log "TRIGGER fired (HOME=$HOME USER=$USER WATCH=$WATCH_DIR)"
sleep 2

file_count=$(find "$WATCH_DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) 2>/dev/null | wc -l | tr -d ' ')
log "  found $file_count files to check"

while IFS= read -r f; do
  if xattr -l "$f" 2>/dev/null | grep -q "$MARKER_XATTR"; then
    continue
  fi

  dims=$(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk '/pixel/ {print $2}' | tr '\n' ' ')
  w=$(echo "$dims" | awk '{print $1}')
  h=$(echo "$dims" | awk '{print $2}')

  if [[ -z "$w" || -z "$h" ]]; then
    continue
  fi

  max=$(( w > h ? w : h ))

  if (( max > MAX_DIM )); then
    before_size=$(stat -f%z "$f")
    sips -Z "$MAX_DIM" "$f" >/dev/null 2>&1 || { log "RESIZE FAIL: $f"; continue; }
    after_size=$(stat -f%z "$f")
    saved=$(( (before_size - after_size) * 100 / (before_size > 0 ? before_size : 1) ))
    xattr -w "$MARKER_XATTR" "1" "$f" 2>/dev/null || true
    log "RESIZED: $(basename "$f") ${w}x${h} -> fit ${MAX_DIM}px (${saved}% smaller)"
  else
    xattr -w "$MARKER_XATTR" "1" "$f" 2>/dev/null || true
    log "SKIP (already small): $(basename "$f") ${w}x${h}"
  fi
done < <(find "$WATCH_DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) 2>/dev/null)

exit 0
