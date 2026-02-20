#!/usr/bin/env bash
set -euo pipefail

# LockClaw build script
# Usage:
#   scripts/build.sh              # builds LockClaw hardened image (default)
#   scripts/build.sh lockclaw     # same as above
#   scripts/build.sh upstream     # clones + builds upstream OpenClaw only
#   scripts/build.sh nix          # Nix home-manager path

MODE="${1:-lockclaw}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_TAG="${IMAGE_TAG:-lockclaw:latest}"

case "$MODE" in
  lockclaw)
    echo "Building LockClaw hardened image..."
    (cd "$ROOT_DIR" && docker build -t "$IMAGE_TAG" .)
    echo ""
    echo "Built: $IMAGE_TAG"
    echo "Run:   docker run -d --name lockclaw --cap-add NET_ADMIN --cap-add AUDIT_WRITE -p 2222:22 $IMAGE_TAG"
    echo "Shell: docker exec -it lockclaw bash"
    echo "Test:  docker exec lockclaw /opt/lockclaw/scripts/test-smoke.sh"
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

    # Verify commit SHA if pinned (supply-chain integrity)
    OPENCLAW_SHA="${OPENCLAW_SHA:-}"
    if [ -n "$OPENCLAW_SHA" ]; then
      ACTUAL_SHA="$(git -C "$OPENCLAW_DIR" rev-parse HEAD)"
      if [ "$ACTUAL_SHA" != "$OPENCLAW_SHA" ]; then
        echo "FATAL: SHA mismatch. Expected $OPENCLAW_SHA, got $ACTUAL_SHA" >&2
        exit 1
      fi
      echo "Verified upstream commit SHA: $ACTUAL_SHA"
    else
      echo "WARN: OPENCLAW_SHA not set. Tag-only checkout without commit verification." >&2
    fi

    (cd "$OPENCLAW_DIR" && docker build -t openclaw:local -f Dockerfile .)
    (cd "$OPENCLAW_DIR" && docker compose run --rm openclaw-cli onboard)
    (cd "$OPENCLAW_DIR" && docker compose up -d openclaw-gateway)
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
    echo "Usage: $0 [lockclaw|upstream|nix]" >&2
    exit 1
    ;;
esac
