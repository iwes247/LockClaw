#!/usr/bin/env bash
set -euo pipefail

# LockClaw Appliance — static audit script
# Validates overlays without needing to build any image.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_AUDIT="${ROOT_DIR}/lockclaw-core/audit/audit.sh"

if [ ! -f "$CORE_AUDIT" ]; then
    echo "ERROR: lockclaw-core not found. Expected at: $CORE_AUDIT" >&2
    exit 1
fi

chmod +x "$CORE_AUDIT"
exec "$CORE_AUDIT" \
    --overlay-dir "$ROOT_DIR/overlays" \
    --mode appliance
