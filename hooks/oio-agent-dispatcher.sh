#!/usr/bin/env bash
# Register OIO as a supported agent in Omarchy's dispatcher.
# Safe to run repeatedly: removes any stale oio) block first, then inserts
# the current one, so re-running also upgrades an existing registration.
# Elevates itself when not running as root, so callers can just invoke it.

set -e

OMARCHY_AGENT="/usr/bin/omarchy-agent"

if [[ ! -f "$OMARCHY_AGENT" ]]; then
  echo "  - $OMARCHY_AGENT not found; skipping dispatcher registration."
  exit 0
fi

# Elevate before any write to the system file.
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

echo "  - Registering/updating oio dispatcher in $OMARCHY_AGENT..."

# Remove any existing oio) block first.
_PYTMP=$(mktemp /tmp/oio-dispatcher-XXXXXX.py)
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
PYEOF
python3 "$_PYTMP" "$OMARCHY_AGENT"
rm -f "$_PYTMP"

# Insert the (updated) oio) case before the LAST '*)' (the agent case),
# not the one in the argument-parsing loop near the top of the file.
_PYTMP=$(mktemp /tmp/oio-dispatcher-XXXXXX.py)
cat > "$_PYTMP" <<'PYEOF'
import sys
p = sys.argv[1]
lines = open(p).read().splitlines(keepends=True)
out = []
inserted = False
last_star = None
for i, line in enumerate(lines):
    if line.strip() == '*)':
        last_star = i
for i, line in enumerate(lines):
    if not inserted and i == last_star:
        out.append("oio)\n")
        out.append("  command=(oio)\n")
        out.append('  [[ -n ${prompt:-} ]] && command+=(-- "$prompt")\n')
        out.append("  ;;\n")
        out.append("\n")
        inserted = True
    out.append(line)
if not inserted:
    print("Could not find insertion point in omarchy-agent", file=sys.stderr)
    sys.exit(1)
open(p, "w").write("".join(out))
print("Dispatcher registered.")
PYEOF
python3 "$_PYTMP" "$OMARCHY_AGENT"
rm -f "$_PYTMP"
