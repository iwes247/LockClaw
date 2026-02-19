#!/usr/bin/env bash
set -euo pipefail

# Uses only documented OpenClaw build/install paths:
# - Docker: docker build + compose onboard/up
# - Nix: home-manager switch with nix-openclaw flake

MODE="${1:-docker}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$MODE" in
  docker)
    OPENCLAW_REF="${OPENCLAW_REF:-main}"
    OPENCLAW_DIR="${OPENCLAW_DIR:-$ROOT_DIR/.upstream/openclaw}"
    mkdir -p "$(dirname "$OPENCLAW_DIR")"

    if [ ! -d "$OPENCLAW_DIR/.git" ]; then
      git clone https://github.com/openclaw/openclaw.git "$OPENCLAW_DIR"
    fi

    git -C "$OPENCLAW_DIR" fetch origin
    git -C "$OPENCLAW_DIR" checkout "$OPENCLAW_REF"

    docker -C "$OPENCLAW_DIR" build -t openclaw:local -f Dockerfile .
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
    echo "Usage: $0 [docker|nix]" >&2
    exit 1
    ;;
esac
