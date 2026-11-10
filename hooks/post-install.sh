#!/usr/bin/env bash
set -e

PLUGIN_DIR="$HOME/.config/omarchy/plugins/right9code.oio"
OIO_SRC_DIR="$HOME/Projects/r9oio"
BIN_DIR="$HOME/.local/bin"
STUB_PATH="$BIN_DIR/oio"
APPS_DIR="$HOME/.local/share/applications"
MENU_EXT_DIR="$HOME/.config/omarchy/extensions"
THEME_HOOK_DIR="$HOME/.config/omarchy/hooks/theme-set.d"
DEFAULTS_DIR="$HOME/.config/omarchy/defaults"
REPO_URL="https://github.com/right9code/r9oio.git"

echo "[Omarchy OIO] Initializing OIO setup..."

# 0. Ask for sudo upfront (cached credentials for dependency install)
if [ "$EUID" -ne 0 ]; then
  echo "[Omarchy OIO] Requesting sudo for dependency installation (if needed)..."
  sudo -v 2>/dev/null || echo "[Omarchy OIO] sudo not available; dependency auto-install may fail."
fi

# 1. Check/install dependencies
echo "[Omarchy OIO] Checking dependencies..."

# git
if ! command -v git &> /dev/null; then
  echo "[Omarchy OIO] git not found. Installing..."
  if command -v pacman &> /dev/null; then
    sudo pacman -S --noconfirm git || { echo "Failed to install git"; exit 1; }
  elif command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y git || { echo "Failed to install git"; exit 1; }
  else
    echo "Error: git not found and no supported package manager. Please install git manually."
    exit 1
  fi
fi

# node (via mise preferred)
if ! command -v node &> /dev/null; then
  if command -v mise &> /dev/null; then
    echo "[Omarchy OIO] Installing Node via mise..."
    mise use -g --quiet node@22 2>/dev/null || mise install node@22 2>/dev/null || true
    eval "$(mise env 2>/dev/null)" || true
  fi
fi
if ! command -v node &> /dev/null; then
  echo "Error: Node.js not found. Please install Node 20.19+ / 22.12+ (e.g. via mise)."
  exit 1
fi

# npm
if ! command -v npm &> /dev/null; then
  echo "Error: npm not found (should ship with Node)."
  exit 1
fi

echo "[Omarchy OIO] Dependencies OK: git=$(git --version | head -1), node=$(node --version), npm=$(npm --version)"

# 2. Resolve/install OIO repo
mkdir -p "$HOME/Projects"
if [ ! -d "$OIO_SRC_DIR/.git" ]; then
  echo "[Omarchy OIO] Repository not found at $OIO_SRC_DIR. Cloning..."
  git clone "$REPO_URL" "$OIO_SRC_DIR"
else
  echo "[Omarchy OIO] Repository exists. Pulling latest..."
  cd "$OIO_SRC_DIR"
  git pull --ff-only origin main 2>/dev/null || echo "[Omarchy OIO] Pull skipped (not fast-forwardable)."
fi

# 3. Install dependencies & build OIO
cd "$OIO_SRC_DIR"
echo "[Omarchy OIO] Installing OIO dependencies..."
npm install --ignore-scripts

echo "[Omarchy OIO] Building OIO..."
npm run build

# 4. Link binary stub into ~/.local/bin/oio
mkdir -p "$BIN_DIR"
if [ -e "$STUB_PATH" ] && [ ! -L "$STUB_PATH" ]; then
  rm -f "$STUB_PATH"
fi
ln -sfn "$OIO_SRC_DIR/dist/cli.mjs" "$STUB_PATH"
chmod +x "$OIO_SRC_DIR/dist/cli.mjs"
echo "[Omarchy OIO] Linked $STUB_PATH -> $OIO_SRC_DIR/dist/cli.mjs"

# 5. Create Desktop Entry
mkdir -p "$APPS_DIR"
cat << DESKTOP_EOF > "$APPS_DIR/oio.desktop"
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

# 6. Add theme sync hook
mkdir -p "$THEME_HOOK_DIR"
cat << 'HOOK_EOF' > "$THEME_HOOK_DIR/99-oio-theme.sh"
#!/usr/bin/env bash
THEME_NAME="$1"
OIO_CFG="$HOME/.config/oio"
mkdir -p "$OIO_CFG"
echo "{\"theme\": \"$THEME_NAME\"}" > "$OIO_CFG/omarchy-theme.json"
HOOK_EOF
chmod +x "$THEME_HOOK_DIR/99-oio-theme.sh"

# 7. Add OIO to Omarchy Menu
mkdir -p "$MENU_EXT_DIR"
cat << 'MENU_EOF' > "$MENU_EXT_DIR/omarchy-menu.jsonc"
{
  "setup.default.agent.oio": {
    "icon": "󰚩",
    "label": "OIO",
    "when": "[[ -d $HOME/.config/omarchy/plugins/right9code.oio ]]",
    "checked": "[[ \"$(cat ~/.config/omarchy/defaults/agent 2>/dev/null)\" == \"oio\" ]]",
    "action": "mkdir -p ~/.config/omarchy/defaults && echo oio > ~/.config/omarchy/defaults/agent && omarchy menu refresh && notify-send 'Default Agent' 'Set to OIO'"
  }
}
MENU_EOF
omarchy menu refresh 2>/dev/null || true

# 8. Register OIO dispatcher in omarchy-agent (sudo) so the
#    SUPER+SHIFT+CTRL+A shortcut and `omarchy agent` can launch it.
OMARCHY_AGENT="/usr/bin/omarchy-agent"
if [ -f "$OMARCHY_AGENT" ] && ! grep -q '^oio)$' "$OMARCHY_AGENT"; then
  echo "[Omarchy OIO] Registering oio dispatcher in $OMARCHY_AGENT (sudo)..."
  sudo python3 - "$OMARCHY_AGENT" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
block = "oio)\n  command=(oio)\n  [[ -n ${prompt:-} ]] && command+=(\"$prompt\")\n  ;;\n\n"
marker = "tau)\n"
if marker in s:
    s = s.replace(marker, block + marker, 1)
else:
    # fallback: insert before the catch-all *)
    s = s.replace("*)\n  echo \"Unsupported default agent", block + "*)\n  echo \"Unsupported default agent", 1)
open(p, "w").write(s)
PY
fi

# 9. Set OIO as default agent
mkdir -p "$DEFAULTS_DIR"
echo "oio" > "$DEFAULTS_DIR/agent"

echo "[Omarchy OIO] Installation completed successfully!"
echo "[Omarchy OIO] Run 'oio --version' to verify."
