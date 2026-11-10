# Omarchy OIO Agent Integration

Native integration for the [OIO AI Agent](https://github.com/right9code/r9oio) into the Omarchy Quattro desktop environment.

## Features
- **Binary Link**: Builds and links `oio` into `~/.local/bin/oio`.
- **Omarchy Launcher Integration**: Registers `oio.desktop` using `omarchy-launch-tui`.
- **Default Agent Integration**: Plugs into Omarchy's `setup.default.agent` menu and sets OIO as the active default coding agent.
- **Shortcut Support**: Triggers via `SUPER + SHIFT + CTRL + A` or `omarchy agent`.
- **Omarchy Theme Sync**: Reacts to Omarchy theme changes via `~/.config/omarchy/hooks/theme-set.d/`.
- **Dependency Check**: Verifies/installs git, Node.js, npm automatically.

## Installation (Omarchy)

### Part 1: Install OIO (no sudo required)
```bash
omarchy plugin add https://github.com/right9code/omarchy-oio.git --enable
```
This clones, builds, and links OIO. The floating terminal will show progress.

### Part 2: Register dispatcher (requires sudo)
After Part 1 completes, run this in your terminal:
```bash
sudo python3 -c "
p='/usr/bin/omarchy-agent'
lines=open(p).read().splitlines(keepends=True)
out=[]; skip=False
for l in lines:
    if l.strip()=='oio)': skip=True; continue
    if skip and l.strip()==';;': skip=False; continue
    if skip: continue
    out.append(l)
# Insert oio case before tau case
block='oio)\n  command=(oio)\n  [[ -n \${prompt:-} ]] && command+=(\"\$prompt\")\n  ;;\n\n'
marker='tau)\n'
text=''.join(out)
if marker in text:
    text=text.replace(marker, block+marker, 1)
open(p,'w').write(text)
print('Dispatcher registered.')
"
```

## Manual Installation
```bash
chmod +x hooks/post-install.sh
./hooks/post-install.sh
```

## Uninstallation
```bash
chmod +x hooks/post-remove.sh
./hooks/post-remove.sh
```
Or via Omarchy:
```bash
omarchy plugin remove right9code.oio --yes
```