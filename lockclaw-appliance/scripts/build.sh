#!/usr/bin/env bash
set -euo pipefail

# LockClaw Appliance — build script
# Usage:
#   scripts/build.sh              # build Docker test image (default)
#   scripts/build.sh docker       # same
#   scripts/build.sh upstream     # clone + build upstream OpenClaw
#   scripts/build.sh nix          # Nix home-manager path

MODE="${1:-docker}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_TAG="${IMAGE_TAG:-lockclaw-appliance:test}"

case "$MODE" in
    docker)
        echo "Building LockClaw Appliance test image..."
        (cd "$ROOT_DIR" && docker build -t "$IMAGE_TAG" .)
        echo ""
        echo "Built: $IMAGE_TAG"
        echo "Run:"
        echo "  docker run -d --name lockclaw-appliance \\"
        echo "    --cap-add NET_ADMIN \\"
        echo "    --cap-add AUDIT_WRITE \\"
        echo "    -e SSH_PUBLIC_KEY=\"\$(cat ~/.ssh/id_ed25519.pub)\" \\"
        echo "    -p 2222:22 $IMAGE_TAG"
        ;;

    upstream)
        OPENCLAW_REF="${OPENCLAW_REF:-v2026.2.19}"
        OPENCLAW_DIR="${OPENCLAW_DIR:-$ROOT_DIR/.upstream/openclaw}"
        mkdir -p "$(dirname "$OPENCLAW_DIR")"

        if [ ! -d "$OPENCLAW_DIR/.git" ]; then
            git clone https://github.com/openclaw/openclaw.git "$OPENCLAW_DIR"
        fi

        git -C "$OPENCLAW_DIR" fetch origin
        git -C "$OPENCLAW_DIR" checkout "$OPENCLAW_REF"

        OPENCLAW_SHA="${OPENCLAW_SHA:-}"
        if [ -n "$OPENCLAW_SHA" ]; then
            ACTUAL_SHA="$(git -C "$OPENCLAW_DIR" rev-parse HEAD)"
            if [ "$ACTUAL_SHA" != "$OPENCLAW_SHA" ]; then
                echo "FATAL: SHA mismatch. Expected $OPENCLAW_SHA, got $ACTUAL_SHA" >&2
                exit 1
            fi
            echo "Verified upstream commit SHA: $ACTUAL_SHA"
        else
            echo "WARN: OPENCLAW_SHA not set." >&2
        fi

        (cd "$OPENCLAW_DIR" && docker build -t openclaw:local -f Dockerfile .)
        ;;

    nix)
        HM_TARGET="${HM_TARGET:-}"
        if [ -z "$HM_TARGET" ]; then
            echo "Set HM_TARGET (example: export HM_TARGET=youruser)" >&2
            exit 1
        fi
        (cd "$ROOT_DIR" && home-manager switch --flake ".#${HM_TARGET}")
        ;;

    *)
        echo "Usage: $0 [docker|upstream|nix]" >&2
        exit 1
        ;;
esac
