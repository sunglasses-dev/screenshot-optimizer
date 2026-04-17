#!/bin/bash
# screenshot-optimizer uninstaller

set -uo pipefail

INSTALL_DIR="${HOME}/.screenshot-optimizer"
PLIST_PATH="${HOME}/Library/LaunchAgents/com.screenshot-optimizer.plist"

echo "Uninstalling screenshot-optimizer..."

if [[ -f "$PLIST_PATH" ]]; then
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  rm -f "$PLIST_PATH"
  echo "  removed LaunchAgent"
fi

if [[ -d "$INSTALL_DIR" ]]; then
  rm -rf "$INSTALL_DIR"
  echo "  removed $INSTALL_DIR"
fi

echo ""
echo "Screenshot save location was NOT changed — if you moved it to ~/Pictures/Screenshots,"
echo "revert with: defaults delete com.apple.screencapture location && killall SystemUIServer"
echo ""
echo "Done."
