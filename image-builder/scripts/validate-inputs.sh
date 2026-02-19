#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLAVOR_FILE="$ROOT_DIR/image-builder/config/flavor.env"

fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "PASS: $*"; }

[ -f "$FLAVOR_FILE" ] || fail "Missing $FLAVOR_FILE (copy flavor.env.example first)"
# shellcheck disable=SC1090
source "$FLAVOR_FILE"

[ -n "${DISTRO_NAME:-}" ] || fail "DISTRO_NAME must be set"
[ -n "${OPENCLAW_UPSTREAM:-}" ] || fail "OPENCLAW_UPSTREAM must be set"
[ -n "${OPENCLAW_REF:-}" ] || fail "OPENCLAW_REF must be set"
[ -n "${TARGET_ARCH:-}" ] || fail "TARGET_ARCH must be set"

# Validate required repo structure remains present
required=(
  "$ROOT_DIR/overlays/etc/security/sysctl.conf"
  "$ROOT_DIR/overlays/etc/network/NetworkManager.conf"
  "$ROOT_DIR/packages/security-defaults.txt"
  "$ROOT_DIR/packages/network-defaults.txt"
  "$ROOT_DIR/scripts/test-smoke.sh"
)
for file in "${required[@]}"; do
  [ -f "$file" ] || fail "Required file missing: $file"
done

if [ "${IMAGE_TOOLCHAIN:-UNSET}" = "UNSET" ]; then
  echo "WARN: IMAGE_TOOLCHAIN is UNSET. Build targets will remain stubs."
fi

pass "image-builder inputs validated"
