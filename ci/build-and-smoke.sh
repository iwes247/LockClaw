#!/usr/bin/env bash
set -euo pipefail

./scripts/audit.sh
# ./scripts/build.sh docker   # enable in CI environment with Docker available
MOLTCLAW_CI="${MOLTCLAW_CI:-0}" ./scripts/test-smoke.sh
