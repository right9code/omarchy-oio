# Omarchy OIO Agent Integration

Native integration for the [OIO AI Agent](https://github.com/right9code/r9oio) into the Omarchy Quattro desktop environment.

## Features
- **Binary Link**: Builds and links `oio` into `~/.local/bin/oio`.
- **Omarchy Launcher Integration**: Registers `oio.desktop` using `omarchy-launch-tui`.
- **Default Agent Integration**: Plugs into Omarchy's `setup.default.agent` menu and sets OIO as the active default coding agent.
- **Shortcut Support**: Triggers via `SUPER + SHIFT + CTRL + A` or `omarchy agent`.
- **Omarchy Theme Sync**: Reacts to Omarchy theme changes via `~/.config/omarchy/hooks/theme-set.d/`.
- **Dependency Check**: Verifies/installs git, Node.js, npm automatically.

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
