#!/usr/bin/env bash
set -euo pipefail

./scripts/audit.sh
# ./scripts/build.sh docker   # enable in CI environment with Docker available
LOCKCLAW_CI="${LOCKCLAW_CI:-0}" ./scripts/test-smoke.sh
