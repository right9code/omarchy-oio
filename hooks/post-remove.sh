#!/usr/bin/env bash
set -e

BIN_STUB="$HOME/.local/bin/oio"
DESKTOP_ENTRY="$HOME/.local/share/applications/oio.desktop"
THEME_HOOK="$HOME/.config/omarchy/hooks/theme-set.d/99-oio-theme.sh"
THEME_CONFIG="$HOME/.config/oio/omarchy-theme.json"
MENU_EXT="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
DEFAULT_AGENT_FILE="$HOME/.config/omarchy/defaults/agent"

echo "[Omarchy OIO] Executing removal and cleanup..."

# 1. Remove binary stub
if [ -f "$BIN_STUB" ] || [ -L "$BIN_STUB" ]; then
  rm -f "$BIN_STUB"
  echo "  - Removed $BIN_STUB"
fi

# 2. Remove desktop launcher
if [ -f "$DESKTOP_ENTRY" ]; then
  rm -f "$DESKTOP_ENTRY"
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  echo "  - Removed $DESKTOP_ENTRY"
fi

# 3. Remove theme sync hook & config
if [ -f "$THEME_HOOK" ]; then
  rm -f "$THEME_HOOK"
  echo "  - Removed $THEME_HOOK"
fi
if [ -f "$THEME_CONFIG" ]; then
  rm -f "$THEME_CONFIG"
  echo "  - Removed $THEME_CONFIG"
fi

# 4. Remove OIO from Omarchy Menu & refresh
if [ -f "$MENU_EXT" ]; then
  echo "{}" > "$MENU_EXT"
  omarchy menu refresh 2>/dev/null || true
  echo "  - Cleared OIO from $MENU_EXT"
fi

# 5. Reset default agent if it is set to oio
if [ -f "$DEFAULT_AGENT_FILE" ] && [ "$(cat "$DEFAULT_AGENT_FILE" 2>/dev/null)" = "oio" ]; then
  rm -f "$DEFAULT_AGENT_FILE"
  echo "  - Reset default agent setting"
fi

# 6. Remove oio dispatcher from omarchy-agent (sudo)
OMARCHY_AGENT="/usr/bin/omarchy-agent"
if [ -f "$OMARCHY_AGENT" ] && grep -q '^oio)$' "$OMARCHY_AGENT"; then
  echo "  - Removing oio dispatcher from $OMARCHY_AGENT (sudo)..."
  sudo sed -i '/^oio)$/,/^  ;;$/d' "$OMARCHY_AGENT" 2>/dev/null || true
fi

echo "[Omarchy OIO] Removal complete!"
