#!/bin/bash
# Stops padkeys, removes the login item and the binary. Your config is kept.
LABEL=com.togkey.padkeys
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist" "$HOME/.local/bin/padkeys"
echo "Removed. Your config is still at ~/.config/padkeys/config.json (delete it if you want)."
