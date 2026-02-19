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
  "$ROOT_DIR/overlays/etc/security/fail2ban/jail.local"
  "$ROOT_DIR/overlays/etc/security/logrotate.d/sudo"
  "$ROOT_DIR/overlays/etc/security/rsyslog.d/50-moltclaw.conf"
  "$ROOT_DIR/overlays/etc/network/NetworkManager.conf"
  "$ROOT_DIR/overlays/etc/network/resolved.conf"
  "$ROOT_DIR/overlays/etc/network/timesyncd.conf"
  "$ROOT_DIR/overlays/etc/network/nftables.conf"
)

for file in "${required[@]}"; do
  [[ -f "$file" ]] || { echo "Missing required file: $file"; exit 1; }
done

echo "All required overlay files are present."

# Content validation — ensure critical policy values are set correctly
echo "Validating policy content..."

# SSH: must disable root login and password auth
SSH_OVERLAY="$ROOT_DIR/overlays/etc/security/sshd_config.d/10-moltclaw-hardening.conf"
grep -Eqi '^\s*PermitRootLogin\s+no' "$SSH_OVERLAY" || { echo "FAIL: SSH overlay missing PermitRootLogin no"; exit 1; }
grep -Eqi '^\s*PasswordAuthentication\s+no' "$SSH_OVERLAY" || { echo "FAIL: SSH overlay missing PasswordAuthentication no"; exit 1; }

# Firewall: must have a deny-default input policy
NFT_OVERLAY="$ROOT_DIR/overlays/etc/network/nftables.conf"
grep -Eqi 'policy\s+drop' "$NFT_OVERLAY" || { echo "FAIL: nftables overlay missing deny-default (policy drop)"; exit 1; }

# Sysctl: must have rp_filter and syncookies
SYSCTL_OVERLAY="$ROOT_DIR/overlays/etc/security/sysctl.conf"
grep -Eqi 'rp_filter\s*=\s*1' "$SYSCTL_OVERLAY" || { echo "FAIL: sysctl missing rp_filter=1"; exit 1; }
grep -Eqi 'tcp_syncookies\s*=\s*1' "$SYSCTL_OVERLAY" || { echo "FAIL: sysctl missing tcp_syncookies=1"; exit 1; }

# Resolver: DNSSEC must not be allow-downgrade
RESOLVED_OVERLAY="$ROOT_DIR/overlays/etc/network/resolved.conf"
if grep -Eqi 'DNSSEC\s*=\s*allow-downgrade' "$RESOLVED_OVERLAY"; then
  echo "FAIL: resolved.conf uses DNSSEC=allow-downgrade (vulnerable to downgrade attacks)"
  exit 1
fi

# Login: must use modern password hashing
LOGIN_OVERLAY="$ROOT_DIR/overlays/etc/security/login.defs"
if grep -Eqi 'ENCRYPT_METHOD\s+SHA512' "$LOGIN_OVERLAY"; then
  echo "WARN: login.defs still uses SHA512; yescrypt recommended"
fi

echo "Policy content validation passed."
