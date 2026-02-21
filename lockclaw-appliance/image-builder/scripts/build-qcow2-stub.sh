#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1090
source "$ROOT_DIR/image-builder/config/flavor.env"

OUT="$ROOT_DIR/image-builder/output/${DISTRO_NAME}-${DISTRO_VERSION}-${TARGET_ARCH}.qcow2.stub"
cat > "$OUT" <<EOF
QCOW2 STUB
-----------
This is a placeholder artifact descriptor.
No authoritative OpenClaw qcow2 tooling was defined in the extracted docs.

Selected placeholders:
- DISTRO_NAME=$DISTRO_NAME
- DISTRO_VERSION=$DISTRO_VERSION
- TARGET_ARCH=$TARGET_ARCH
- OPENCLAW_UPSTREAM=$OPENCLAW_UPSTREAM
- OPENCLAW_REF=$OPENCLAW_REF
- IMAGE_TOOLCHAIN=${IMAGE_TOOLCHAIN:-UNSET}

Next step:
- Choose and wire a real VM image toolchain for qcow2 output.
EOF

echo "Created $OUT"
