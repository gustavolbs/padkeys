#!/bin/bash
# Builds padkeys from source and starts it at login. Safe to run again (it updates the binary and restarts the agent).
set -euo pipefail
cd "$(dirname "$0")"

LABEL=com.togkey.padkeys
BIN="$HOME/.local/bin/padkeys"
CFG="$HOME/.config/padkeys/config.json"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

command -v swiftc >/dev/null || { echo "swiftc not found. Run 'xcode-select --install' first, then run this script again."; exit 1; }

mkdir -p "$(dirname "$BIN")" "$(dirname "$CFG")" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
swiftc -O -o "$BIN" padkeys.swift

if [ -f "$CFG" ]; then
  echo "Keeping your existing config: $CFG"
else
  cp config.example.json "$CFG"
  echo "Created $CFG (edit it to match your keymap)"
fi

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$LABEL</string>
<key>ProgramArguments</key><array><string>$BIN</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
<key>StandardErrorPath</key><string>$HOME/Library/Logs/padkeys.log</string>
</dict></plist>
PLIST

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "padkeys is running. Look for the keyboard icon in the menu bar."
echo "Edit hotkeys, then restart with: launchctl kickstart -k gui/$(id -u)/$LABEL"
