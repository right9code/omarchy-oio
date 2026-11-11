#!/usr/bin/env bash
# Re-apply the OIO dispatcher case after an Omarchy package update, which
# overwrites /usr/bin/omarchy-agent. Non-interactive: never prompts for sudo.

OMARCHY_AGENT="/usr/bin/omarchy-agent"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/right9code.oio"
STABLE_DIR="$HOME/.config/oio"
DISPATCHER=""

if [[ -x "$PLUGIN_DIR/hooks/oio-agent-dispatcher.sh" ]]; then
  DISPATCHER="$PLUGIN_DIR/hooks/oio-agent-dispatcher.sh"
elif [[ -x "$STABLE_DIR/oio-agent-dispatcher.sh" ]]; then
  DISPATCHER="$STABLE_DIR/oio-agent-dispatcher.sh"
fi

[[ -f "$OMARCHY_AGENT" ]] || exit 0
grep -q '^oio)$' "$OMARCHY_AGENT" && exit 0

# Nothing to do if we have no dispatcher script.
[[ -n "$DISPATCHER" ]] || exit 0

if sudo -n bash "$DISPATCHER" >/dev/null 2>&1; then
  omarchy-notification-send "OIO" "Agent dispatcher re-registered after update." 2>/dev/null || true
else
  omarchy-notification-send "OIO" "Agent dispatcher needs re-registration. Run: omarchy plugin reinstall right9code.oio" 2>/dev/null || true
fi
exit 0
