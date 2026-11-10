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
  if [ -t 0 ]; then
    echo "  - Removing oio dispatcher from $OMARCHY_AGENT (sudo)..."
    sudo sed -i '/^oio)$/,/^  ;;$/d' "$OMARCHY_AGENT" 2>/dev/null || true
  else
    echo "  - Skipping sudo dispatcher removal (no TTY). Run manually:"
    echo "      sudo sed -i '/^oio)$/,/^  ;;$/d' $OMARCHY_AGENT"
  fi
fi

# 7. Remove user-level Hyprland shortcut (no sudo)
BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"
if [ -f "$BINDINGS_FILE" ] && grep -q 'right9code.oio shortcut' "$BINDINGS_FILE"; then
  python3 - "$BINDINGS_FILE" <<'PY'
import sys
p = sys.argv[1]
lines = open(p).read().splitlines(keepends=True)
out = []
inside = False
for line in lines:
    if 'right9code.oio shortcut >>>' in line:
        inside = True
        continue
    if 'right9code.oio shortcut <<<' in line:
        inside = False
        continue
    if inside:
        continue
    out.append(line)
open(p, 'w').write(''.join(out))
PY
  echo "  - Removed OIO shortcut from $BINDINGS_FILE"
fi

# 8. Remove stable uninstaller copy
rm -f "$HOME/.config/oio/uninstall.sh"
rmdir "$HOME/.config/oio" 2>/dev/null || true

# 9. Remove source repo? (kept by default; chat/credentials stay)
# Uncomment the next line to also delete ~/Projects/r9oio:
# rm -rf "$HOME/Projects/r9oio"

echo "[Omarchy OIO] Removal complete!"
