#!/bin/bash
# screenshot-optimizer installer
# https://github.com/sunglasses-dev/screenshot-optimizer

set -euo pipefail

echo ""
echo "screenshot-optimizer — auto-downscale screenshots for Claude/any LLM"
echo "https://github.com/sunglasses-dev/screenshot-optimizer"
echo ""

# --- macOS check ---
if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: this tool is macOS-only (uses sips, launchctl, defaults)."
  exit 1
fi

INSTALL_DIR="${HOME}/.screenshot-optimizer"
PLIST_PATH="${HOME}/Library/LaunchAgents/com.screenshot-optimizer.plist"
REPO_URL="https://raw.githubusercontent.com/sunglasses-dev/screenshot-optimizer/main"

mkdir -p "$INSTALL_DIR"

# --- Download or copy the script ---
if [[ -f "$(dirname "$0")/screenshot-optimizer.sh" ]]; then
  cp "$(dirname "$0")/screenshot-optimizer.sh" "${INSTALL_DIR}/screenshot-optimizer.sh"
else
  echo "Downloading script..."
  curl -fsSL "${REPO_URL}/screenshot-optimizer.sh" -o "${INSTALL_DIR}/screenshot-optimizer.sh"
fi
chmod +x "${INSTALL_DIR}/screenshot-optimizer.sh"

# --- Ask about screenshot location ---
CURRENT_LOC=$(defaults read com.apple.screencapture location 2>/dev/null || echo "${HOME}/Desktop")
RECOMMENDED="${HOME}/Pictures/Screenshots"

echo ""
echo "Current screenshot save location: $CURRENT_LOC"

# Detect TCC-protected paths. LaunchAgents can't read ~/Desktop, ~/Documents, ~/Downloads.
TCC_BLOCKED=0
case "$CURRENT_LOC" in
  "${HOME}/Desktop"|"${HOME}/Desktop/"*|\
  "${HOME}/Documents"|"${HOME}/Documents/"*|\
  "${HOME}/Downloads"|"${HOME}/Downloads/"*)
    TCC_BLOCKED=1
    ;;
esac

WATCH_DIR="$CURRENT_LOC"
if [[ $TCC_BLOCKED -eq 1 ]]; then
  echo ""
  echo "  This path is TCC-protected. macOS will silently block the daemon from"
  echo "  reading it (daemon fires, finds 0 files, nothing happens)."
  echo "  Moving to $RECOMMENDED so things actually work."
  echo ""
  mkdir -p "$RECOMMENDED"
  defaults write com.apple.screencapture location "$RECOMMENDED"
  killall SystemUIServer 2>/dev/null || true
  WATCH_DIR="$RECOMMENDED"
  echo "  -> screenshots now save to $RECOMMENDED"
  echo "  -> revert anytime: defaults delete com.apple.screencapture location && killall SystemUIServer"
else
  echo "  -> not TCC-protected, keeping as-is"
  mkdir -p "$WATCH_DIR"
fi

# --- Write LaunchAgent plist ---
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.screenshot-optimizer</string>
    <key>ProgramArguments</key>
    <array>
        <string>${INSTALL_DIR}/screenshot-optimizer.sh</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>SCREENSHOT_OPTIMIZER_DIR</key>
        <string>${WATCH_DIR}</string>
    </dict>
    <key>WatchPaths</key>
    <array>
        <string>${WATCH_DIR}</string>
    </array>
    <key>ThrottleInterval</key>
    <integer>1</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${INSTALL_DIR}/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${INSTALL_DIR}/stderr.log</string>
</dict>
</plist>
EOF

# --- Load it ---
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo ""
echo "DONE. Take a screenshot and it'll auto-resize within ~2 seconds."
echo ""
echo "Log:       tail -f ${INSTALL_DIR}/optimizer.log"
echo "Uninstall: curl -fsSL ${REPO_URL}/uninstall.sh | bash"
echo ""
