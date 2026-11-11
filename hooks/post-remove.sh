#!/usr/bin/env bash
set -e

BIN_STUB="$HOME/.local/bin/oio"
DESKTOP_ENTRY="$HOME/.local/share/applications/oio.desktop"
THEME_HOOK="$HOME/.config/omarchy/hooks/theme-set.d/99-oio-theme.sh"
THEME_CONFIG="$HOME/.config/oio/omarchy-theme.json"
MENU_EXT="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
DEFAULT_AGENT_FILE="$HOME/.config/omarchy/defaults/agent"
POST_UPDATE_HOOK="$HOME/.config/omarchy/hooks/post-update.d/99-oio-agent-dispatcher.sh"
STABLE_DISPATCHER="$HOME/.config/oio/oio-agent-dispatcher.sh"
STABLE_DIR="$HOME/.local/share/oio"
OIO_CFG="$HOME/.config/oio"

echo "[Omarchy OIO] Executing removal and cleanup..."

pause_before_close() {
  local status=$?
  if (( status == 0 )); then
    echo ""
    read -rt 5 -p 'Closing in 5 s (Enter closes now).' _ || true
  else
    echo ''
    echo 'Removal did not finish; see the messages above.'
    read -rp 'Press Enter to close.' _ || true
  fi
}
[[ -t 0 && -t 1 ]] && trap pause_before_close EXIT

# 1. Remove binary stub
if [ -f "$BIN_STUB" ] || [ -L "$BIN_STUB" ]; then
  rm -f "$BIN_STUB"
  echo "  - Removed $BIN_STUB"
fi

# 1b. Remove stable install location
if [ -d "$STABLE_DIR" ]; then
  rm -rf "$STABLE_DIR"
  echo "  - Removed $STABLE_DIR"
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

# 4. Remove only the OIO block from the shared menu extension file
if [ -f "$MENU_EXT" ]; then
  python3 - "$MENU_EXT" <<'PYEOF'
import os, re, sys
path = sys.argv[1]
begin = "// >>> right9code.oio"
end = "// <<< right9code.oio"
text = open(path).read()
text = re.sub(r"\s*" + re.escape(begin) + r".*?" + re.escape(end) + r"\s*,?\s*", "\n", text, flags=re.S)
# Collapse a now-empty object back to {}.
if re.sub(r"\s", "", text) in ("{}", ""):
    text = "{}\n"
open(path, "w").write(text)
print("  - Removed OIO block from menu extension.")
PYEOF
  omarchy menu refresh 2>/dev/null || true
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
  _PYTMP=$(mktemp /tmp/oio-remove-dispatcher-XXXXXX.py)
  cat > "$_PYTMP" <<'PYEOF'
import sys
p = sys.argv[1]
lines = open(p).read().splitlines(keepends=True)
out = []
skip = False
for line in lines:
    if line.strip() == 'oio)':
        skip = True
        continue
    if skip and line.strip() == ';;':
        skip = False
        continue
    if skip:
        continue
    out.append(line)
open(p, 'w').write(''.join(out))
print("Dispatcher removed.")
PYEOF
  sudo python3 "$_PYTMP" "$OMARCHY_AGENT" && rm -f "$_PYTMP" || { echo "  (sudo failed; run manually: sudo python3 $_PYTMP $OMARCHY_AGENT)"; }
fi

# 7. Remove post-update hook and stable dispatcher copy
if [ -f "$POST_UPDATE_HOOK" ]; then
  rm -f "$POST_UPDATE_HOOK"
  echo "  - Removed post-update hook"
fi
if [ -f "$STABLE_DISPATCHER" ]; then
  rm -f "$STABLE_DISPATCHER"
  echo "  - Removed stable dispatcher copy"
fi

# 8. Remove stable uninstaller copy
rm -f "$OIO_CFG/uninstall.sh"
rmdir "$OIO_CFG" 2>/dev/null || true

echo "[Omarchy OIO] Removal complete!"
