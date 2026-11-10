#!/usr/bin/env bash
set -euo pipefail

echo "[Omarchy OIO] Initializing OIO setup..."

# Keep the terminal open on failure so the user can read errors (pym.omadroid pattern).
pause_before_close() {
  local status=$?
  if (( status == 0 )); then
    echo ""
    read -rt 10 -p 'Closing in 10 s (Enter closes now).' _ || true
  else
    echo ''
    echo 'Setup did not finish; see the messages above.'
    read -rp 'Press Enter to close.' _ || true
  fi
}
[[ -t 0 && -t 1 ]] && trap pause_before_close EXIT

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

# Link binary
mkdir -p "$HOME/.local/bin"
ln -sf "$OIO_DIR/dist/cli.mjs" "$HOME/.local/bin/oio"
echo "[Omarchy OIO] Linked $HOME/.local/bin/oio -> $OIO_DIR/dist/cli.mjs"

# Register dispatcher in /usr/bin/omarchy-agent (requires sudo)
OMARCHY_AGENT="/usr/bin/omarchy-agent"
if [ -f "$OMARCHY_AGENT" ] && ! grep -q '^oio)$' "$OMARCHY_AGENT"; then
  clear 2>/dev/null || true
  echo ""
  echo "================================================"
  echo "  *** SUDO REQUIRED ***"
  echo "  Registering oio dispatcher in $OMARCHY_AGENT"
  echo "  You will be asked for your sudo password."
  echo "================================================"
  echo ""
  read -rp 'Press Enter to continue to the sudo step...' _ || true
  echo ""
  _PYTMP=$(mktemp /tmp/oio-dispatcher-XXXXXX.py)
  cat > "$_PYTMP" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
block = "oio)\n  command=(oio)\n  [[ -n ${prompt:-} ]] && command+=(\"$prompt\")\n  ;;\n\n"
marker = "tau)\n"
if marker in s:
    s = s.replace(marker, block + marker, 1)
else:
    s = s.replace("*)\n  echo \"Unsupported default agent\"", block + "*)\n  echo \"Unsupported default agent\"", 1)
open(p, "w").write(s)
print("Dispatcher registered successfully.")
PYEOF
  if sudo python3 "$_PYTMP" "$OMARCHY_AGENT"; then
    echo ""
    echo "[Omarchy OIO] Dispatcher registered."
  else
    echo ""
    echo "[Omarchy OIO] sudo failed. Run this manually in a terminal:"
    echo "  sudo python3 $_PYTMP $OMARCHY_AGENT"
    echo "(Then remove $_PYTMP)"
    _PYTMP=""
  fi
  if [ -n "${_PYTMP:-}" ]; then rm -f "$_PYTMP"; fi
fi

# Set default agent
mkdir -p "$HOME/.config/omarchy/defaults"
echo "oio" > "$HOME/.config/omarchy/defaults/agent"
echo "[Omarchy OIO] Default agent set to oio."

# Create stable uninstaller
mkdir -p "$HOME/.config/oio"
cp "$(dirname "$0")/post-remove.sh" "$HOME/.config/oio/uninstall.sh" 2>/dev/null || true
chmod +x "$HOME/.config/oio/uninstall.sh" 2>/dev/null || true

# Theme hook
THEME_HOOK_DIR="$HOME/.config/omarchy/hooks/theme-set.d"
mkdir -p "$THEME_HOOK_DIR"
cat > "$THEME_HOOK_DIR/99-oio-theme.sh" <<'EOF'
#!/usr/bin/env bash
# OIO theme hook - placeholder
EOF
chmod +x "$THEME_HOOK_DIR/99-oio-theme.sh"

echo ""
echo "[Omarchy OIO] Installation completed successfully!"
echo "[Omarchy OIO] Run 'oio --version' to verify."