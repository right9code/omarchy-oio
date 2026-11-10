#!/usr/bin/env bash
set -e

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

# Copy built files to a stable location (so deleting the repo won't break oio)
OIO_STABLE="$HOME/.local/share/oio"
mkdir -p "$OIO_STABLE/dist" "$OIO_STABLE/scripts"
rm -rf "$OIO_STABLE/dist"/* "$OIO_STABLE/scripts"/*
cp -r "$OIO_DIR/dist/." "$OIO_STABLE/dist/"
cp "$OIO_DIR"/scripts/*.mjs "$OIO_STABLE/scripts/" 2>/dev/null || true
cp "$OIO_DIR/package.json" "$OIO_STABLE/package.json" 2>/dev/null || true
chmod +x "$OIO_STABLE/dist/cli.mjs"

# Link binary to stable location
mkdir -p "$HOME/.local/bin"
ln -sf "$OIO_STABLE/dist/cli.mjs" "$HOME/.local/bin/oio"
echo "[Omarchy OIO] Installed to $OIO_STABLE"
echo "[Omarchy OIO] Linked $HOME/.local/bin/oio -> $OIO_STABLE/dist/cli.mjs"

echo ""
echo "[Omarchy OIO] NOTE: Dispatcher not registered (requires sudo)."
echo "  Run the sudo command from README.md Part 2 to enable 'omarchy agent'."
echo ""
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
echo "=================================================="
echo "        Installation completed successfully!      "
echo "=================================================="
echo "[Omarchy OIO] Run 'oio --version' to verify."