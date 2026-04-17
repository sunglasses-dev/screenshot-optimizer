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
echo "CURRENT screenshot save location: $CURRENT_LOC"
echo ""
echo "macOS restricts LaunchAgents from reading ~/Desktop, ~/Documents, ~/Downloads"
echo "(silent TCC block — daemon will fire but find 0 files)."
echo ""
echo "Recommended: move screenshots to $RECOMMENDED"
echo "Your Cmd+Shift+5 / Cmd+Shift+4 shortcuts keep working — only the save path changes."
echo ""
read -p "Move screenshot save location to $RECOMMENDED? [Y/n] " -n 1 -r
echo ""

WATCH_DIR="$CURRENT_LOC"
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  mkdir -p "$RECOMMENDED"
  defaults write com.apple.screencapture location "$RECOMMENDED"
  killall SystemUIServer 2>/dev/null || true
  WATCH_DIR="$RECOMMENDED"
  echo "  -> screenshots will now save to $RECOMMENDED"
else
  echo "  -> keeping $CURRENT_LOC"
  echo "  WARNING: if this is ~/Desktop, ~/Documents, or ~/Downloads, the daemon"
  echo "  may silently fail due to macOS TCC. Consider moving later."
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
