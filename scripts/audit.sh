#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required=(
  "$ROOT_DIR/overlays/etc/security/sysctl.conf"
  "$ROOT_DIR/overlays/etc/security/limits.conf"
  "$ROOT_DIR/overlays/etc/security/login.defs"
  "$ROOT_DIR/overlays/etc/security/sudoers.d/10-moltclaw-hardening"
  "$ROOT_DIR/overlays/etc/security/sshd_config.d/10-moltclaw-hardening.conf"
  "$ROOT_DIR/overlays/etc/security/audit/audit.rules"
  "$ROOT_DIR/overlays/etc/security/logging/journald.conf"
  "$ROOT_DIR/overlays/etc/network/NetworkManager.conf"
  "$ROOT_DIR/overlays/etc/network/resolved.conf"
  "$ROOT_DIR/overlays/etc/network/timesyncd.conf"
)

for file in "${required[@]}"; do
  [[ -f "$file" ]] || { echo "Missing required file: $file"; exit 1; }
done

echo "All required overlay files are present."
