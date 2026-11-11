#!/usr/bin/env bash
set -e

REGISTER_ONLY=false
if [[ "${1:-}" == "--register-only" ]]; then
  REGISTER_ONLY=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
MENU_EXT_DIR="$HOME/.config/omarchy/extensions"
THEME_HOOK_DIR="$HOME/.config/omarchy/hooks/theme-set.d"
POST_UPDATE_DIR="$HOME/.config/omarchy/hooks/post-update.d"
DEFAULTS_DIR="$HOME/.config/omarchy/defaults"
OIO_CFG="$HOME/.config/oio"
STABLE_DIR="$HOME/.local/share/oio"
DISPATCHER_SCRIPT="$PLUGIN_DIR/hooks/oio-agent-dispatcher.sh"
STABLE_DISPATCHER="$OIO_CFG/oio-agent-dispatcher.sh"

# ---------------------------------------------------------------------------
# Build (skipped in --register-only mode)
# ---------------------------------------------------------------------------
if [[ "$REGISTER_ONLY" != "true" ]]; then
  echo "[Omarchy OIO] Initializing OIO setup..."

  # Check dependencies
  echo "[Omarchy OIO] Checking dependencies..."
  if ! command -v node >/dev/null 2>&1; then
    echo "[Omarchy OIO] Node.js not found. Installing via mise..."
    if command -v mise >/dev/null 2>&1; then
      mise use -g node@22
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -S --noconfirm nodejs npm
    else
      echo "Please install Node.js 20.19+ or 22.12+ manually."
      exit 1
    fi
  fi

  NODE_VER=$(node -e "console.log(process.version)")
  echo "[Omarchy OIO] Node.js $NODE_VER"

  # Clone or update repo
  OIO_DIR="$HOME/Projects/r9oio"
  if [ -d "$OIO_DIR/.git" ]; then
    echo "[Omarchy OIO] Updating existing repo..."
    cd "$OIO_DIR" && git pull --ff-only
  else
    echo "[Omarchy OIO] Cloning OIO from GitHub..."
    mkdir -p "$HOME/Projects"
    git clone https://github.com/right9code/r9oio.git "$OIO_DIR"
  fi

  cd "$OIO_DIR"

  # Install dependencies (ignore scripts for security)
  echo "[Omarchy OIO] Installing dependencies..."
  npm install --ignore-scripts

  # Build
  echo "[Omarchy OIO] Building OIO..."
  npm run build

  # Copy entire repo to a stable location (so deleting ~/Projects/r9oio won't break oio)
  echo "[Omarchy OIO] Copying to stable location..."
  rm -rf "$STABLE_DIR"
  cp -r "$OIO_DIR" "$STABLE_DIR"
  chmod +x "$STABLE_DIR/dist/cli.mjs"

  # Link binary to stable location
  mkdir -p "$BIN_DIR"
  ln -sf "$STABLE_DIR/dist/cli.mjs" "$BIN_DIR/oio"
  echo "[Omarchy OIO] Installed to $STABLE_DIR"
  echo "[Omarchy OIO] Linked $BIN_DIR/oio -> $STABLE_DIR/dist/cli.mjs"

  # Set default agent
  mkdir -p "$DEFAULTS_DIR"
  echo "oio" > "$DEFAULTS_DIR/agent"
  echo "[Omarchy OIO] Default agent set to oio."

  # Create stable uninstaller + dispatcher script copies
  mkdir -p "$OIO_CFG"
  cp "$PLUGIN_DIR/hooks/post-remove.sh" "$OIO_CFG/uninstall.sh" 2>/dev/null || true
  chmod +x "$OIO_CFG/uninstall.sh" 2>/dev/null || true
  cp "$DISPATCHER_SCRIPT" "$STABLE_DISPATCHER" 2>/dev/null || true
  chmod +x "$STABLE_DISPATCHER" 2>/dev/null || true

  # Theme hook
  mkdir -p "$THEME_HOOK_DIR"
  cat > "$THEME_HOOK_DIR/99-oio-theme.sh" <<'EOF'
#!/usr/bin/env bash
THEME_NAME="$1"
OIO_CFG="$HOME/.config/oio"
mkdir -p "$OIO_CFG"
echo "{\"theme\": \"$THEME_NAME\"}" > "$OIO_CFG/omarchy-theme.json"
EOF
  chmod +x "$THEME_HOOK_DIR/99-oio-theme.sh"

  echo ""
  echo "=================================================="
  echo "        Installation completed successfully!      "
  echo "=================================================="
  echo "[Omarchy OIO] Run 'oio --version' to verify."
  echo ""
fi

# ---------------------------------------------------------------------------
# Registration (runs in both modes; safe to repeat)
# ---------------------------------------------------------------------------
echo "[Omarchy OIO] Registering with Omarchy..."

# 1. Menu extension (merged, marker-delimited so other plugins survive)
mkdir -p "$MENU_EXT_DIR"
MENU_EXT="$MENU_EXT_DIR/omarchy-menu.jsonc"
python3 - "$MENU_EXT" <<'PYEOF'
import os, re, sys
path = sys.argv[1]
begin = "// >>> right9code.oio"
end = "// <<< right9code.oio"
entry = (
    '"setup.default.agent.oio": '
    '{"icon":"\u262f","label":"OIO",'
    '"description":"OIO agent harness",'
    '"when":"[[ -x $HOME/.local/bin/oio ]]",'
    '"checked":"[[ \\"$(omarchy-default-agent)\\" == \\"oio\\" ]]",'
    '"action":"mkdir -p ~/.config/omarchy/defaults && echo oio > ~/.config/omarchy/defaults/agent && omarchy menu refresh && omarchy-launch-tui --app-id=org.omarchy.agent oio"}'
)
text = open(path).read() if os.path.exists(path) else "{}\n"
# Remove any previous OIO block (and a trailing comma if present).
text = re.sub(r"\s*" + re.escape(begin) + r".*?" + re.escape(end) + r"\s*,?\s*", "\n", text, flags=re.S)
idx = text.rfind("}")
if idx == -1:
    raise SystemExit("omarchy-menu.jsonc has no closing brace")
prefix = text[:idx].rstrip()
if not (prefix.endswith("{") or prefix.endswith(",")):
    prefix += ","
block = "\n  " + begin + "\n  " + entry + "\n  " + end + "\n"
text = prefix + block + text[idx:]
open(path, "w").write(text)
print("  - Menu entry registered.")
PYEOF

omarchy menu refresh 2>/dev/null || true

# 2. Desktop entry
mkdir -p "$APPS_DIR"
cat > "$APPS_DIR/oio.desktop" <<DESKTOP_EOF
[Desktop Entry]
Name=OIO Agent
Comment=AI coding agent
TryExec=$PLUGIN_DIR/manifest.json
Exec=omarchy-launch-tui --app-id=org.omarchy.agent oio
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Development;Utility;
StartupNotify=true
DESKTOP_EOF
update-desktop-database "$APPS_DIR" 2>/dev/null || true
echo "  - Desktop entry registered."

# 3. Dispatcher registration (pkexec; non-interactive sudo -n attempt in --register-only mode)
OMARCHY_AGENT="/usr/bin/omarchy-agent"
if [[ -f "$OMARCHY_AGENT" ]]; then
  if grep -q 'command=(oio)$' "$OMARCHY_AGENT"; then
    echo "  - oio dispatcher already registered."
  else
    if [[ "$REGISTER_ONLY" == "true" ]]; then
      if sudo -n bash "$DISPATCHER_SCRIPT" >/dev/null 2>&1; then
        echo "  - oio dispatcher registered."
      else
        echo "  - oio dispatcher missing; run 'omarchy plugin reinstall right9code.oio' to register."
        omarchy-notification-send "OIO" "Agent dispatcher needs registration. Run: omarchy plugin reinstall right9code.oio" 2>/dev/null || true
      fi
    else
      bash "$DISPATCHER_SCRIPT"
    fi
  fi
fi

# 4. Post-update hook (keeps the dispatcher alive across omarchy updates)
mkdir -p "$POST_UPDATE_DIR"
cp "$PLUGIN_DIR/hooks/post-update-agent-dispatcher.sh" "$POST_UPDATE_DIR/99-oio-agent-dispatcher.sh" 2>/dev/null || true
chmod +x "$POST_UPDATE_DIR/99-oio-agent-dispatcher.sh" 2>/dev/null || true
echo "  - Post-update hook installed."

echo "[Omarchy OIO] Registration complete."
