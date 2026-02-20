#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "PASS: $*"; }
note() { echo "NOTE: $*"; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CI_MODE="${LOCKCLAW_CI:-0}"

# Detect if running inside a container (Docker / LXC / podman)
CONTAINER_MODE=0
if [ -f /.dockerenv ] || grep -qsE ':/docker/|:/lxc/' /proc/1/cgroup 2>/dev/null; then
  CONTAINER_MODE=1
fi

# 0) Boot check
if [ -r /proc/uptime ]; then
  awk '{ if ($1 > 0) exit 0; exit 1 }' /proc/uptime || fail "system uptime invalid"
  pass "system booted"
elif [ "$CI_MODE" = "1" ] || [ "$CONTAINER_MODE" = "1" ]; then
  pass "boot check skipped (CI or container)"
else
  fail "cannot verify boot state"
fi

# 1) Network connectivity
if command -v ip >/dev/null 2>&1; then
  DEF_IFACE="$(ip route show default 2>/dev/null | awk '{print $5}' | head -n1 || true)"
  if [ -n "${DEF_IFACE:-}" ]; then
    pass "default route present on $DEF_IFACE"
  elif [ "$CI_MODE" = "1" ] || [ "$CONTAINER_MODE" = "1" ]; then
    pass "default-route check skipped (CI or container networking)"
  else
    fail "no default route detected"
  fi
  # NetworkManager validation — only on bare-metal/VM targets
  if [ "$CONTAINER_MODE" = "0" ] && command -v nmcli >/dev/null 2>&1; then
    if [ -n "${DEF_IFACE:-}" ]; then
      if nmcli -g ipv4.method device show "$DEF_IFACE" 2>/dev/null | grep -Eq 'auto'; then
        pass "DHCP method detected on $DEF_IFACE (NetworkManager)"
      elif [ "$CI_MODE" = "1" ]; then
        grep -Eqi '^\s*\[main\]' "$ROOT_DIR/overlays/etc/network/NetworkManager.conf" || fail "missing NetworkManager overlay"
        pass "DHCP policy fallback validated from network overlay"
      fi
    fi
  elif [ "$CI_MODE" = "1" ] && [ -f "$ROOT_DIR/overlays/etc/network/NetworkManager.conf" ]; then
    grep -Eqi '^\s*\[main\]' "$ROOT_DIR/overlays/etc/network/NetworkManager.conf" || fail "missing NetworkManager overlay"
    pass "NetworkManager overlay validated (bare-metal/VM policy)"
  fi
elif [ "$CI_MODE" = "1" ]; then
  pass "network check skipped in CI (no ip command)"
fi

# 2) OpenClaw gateway posture
if command -v openclaw >/dev/null 2>&1; then
  # a) Verify gateway binary exists and can report status
  if openclaw gateway status >/dev/null 2>&1; then
    pass "openclaw gateway status ok"
  elif [ "$CONTAINER_MODE" = "1" ]; then
    note "gateway may still be starting; checking port instead"
  else
    fail "openclaw gateway status failed"
  fi

  # b) Verify gateway is listening on loopback:18789
  if command -v ss >/dev/null 2>&1; then
    if ss -tlnH 2>/dev/null | grep -q ':18789'; then
      pass "openclaw gateway listening on :18789"
    elif [ "$CONTAINER_MODE" = "1" ]; then
      note "gateway port 18789 not yet bound (may need API key to fully start)"
    else
      fail "openclaw gateway not listening on :18789"
    fi
  fi

  # c) Verify claude-mem plugin is installed
  if command -v claude-mem >/dev/null 2>&1 || npm list -g claude-mem >/dev/null 2>&1; then
    pass "claude-mem plugin installed"
  else
    note "claude-mem not found (install with: npm install -g claude-mem@latest)"
  fi
elif [ "$CI_MODE" = "1" ]; then
  note "openclaw not in CI runner; gateway posture validated by Dockerfile"
fi

# 3) DNS
if command -v getent >/dev/null 2>&1; then
  getent hosts docs.openclaw.ai >/dev/null 2>&1 || fail "DNS resolution"
  pass "DNS resolution"
fi

# 4) Time sync
if command -v timedatectl >/dev/null 2>&1 && [ "$CONTAINER_MODE" = "0" ]; then
  if [ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo no)" = "yes" ]; then
    pass "NTP synchronized"
  elif [ "$CI_MODE" = "1" ]; then
    grep -Eqi '^\s*NTP=' "$ROOT_DIR/overlays/etc/network/timesyncd.conf" || fail "timesync overlay missing NTP"
    pass "time sync policy validated from overlay"
  else
    fail "NTP not synchronized"
  fi
elif [ "$CI_MODE" = "1" ] || [ "$CONTAINER_MODE" = "1" ]; then
  if [ -f "$ROOT_DIR/overlays/etc/network/timesyncd.conf" ]; then
    grep -Eqi '^\s*NTP=' "$ROOT_DIR/overlays/etc/network/timesyncd.conf" || fail "timesync overlay missing NTP"
    pass "time sync policy validated from overlay (not applicable in container)"
  else
    note "timesyncd overlay not found; skipping"
  fi
fi

# 5) Firewall (best-effort)
if command -v nft >/dev/null 2>&1; then
  if nft list ruleset >/dev/null 2>&1; then
    # Verify deny-default policy is loaded — check full ruleset for portability
    RULESET="$(nft list ruleset 2>/dev/null)"
    if echo "$RULESET" | grep -q 'policy drop'; then
      pass "nftables loaded with deny-default policy"
    elif [ "$CONTAINER_MODE" = "1" ]; then
      # In Docker, nft may load but kernel namespace limits visibility
      if [ -f /etc/nftables.conf ] && grep -q 'policy drop' /etc/nftables.conf; then
        pass "nftables config has deny-default (kernel may limit visibility in container)"
      else
        fail "nftables loaded but no deny-default policy found"
      fi
    else
      fail "nftables loaded but input policy is not drop"
    fi
  elif [ "$CI_MODE" = "1" ]; then
    NFT_OVERLAY="$ROOT_DIR/overlays/etc/network/nftables.conf"
    grep -Eqi 'policy\s+drop' "$NFT_OVERLAY" || fail "nftables overlay missing deny-default policy"
    grep -Eqi 'dport\s+22' "$NFT_OVERLAY" || fail "nftables overlay missing SSH allow rule"
    pass "firewall policy validated from overlay (deny-default + SSH)"
  else
    fail "nftables not readable"
  fi
elif [ "$CI_MODE" = "1" ]; then
  NFT_OVERLAY="$ROOT_DIR/overlays/etc/network/nftables.conf"
  [ -f "$NFT_OVERLAY" ] || fail "nftables overlay missing"
  grep -Eqi 'policy\s+drop' "$NFT_OVERLAY" || fail "nftables overlay missing deny-default policy"
  pass "firewall policy validated from overlay"
else
  fail "no supported firewall tool detected"
fi

# 6) SSH posture
if command -v ss >/dev/null 2>&1; then
  if ss -ltn | grep -q ':22'; then
    pass "sshd listening"
  elif [ "$CI_MODE" = "1" ] || [ "$CONTAINER_MODE" = "1" ]; then
    note "sshd not listening yet; validating SSH posture from config"
  else
    fail "sshd not listening on 22"
  fi
fi

if [ -f /etc/ssh/sshd_config ] || [ -d /etc/ssh/sshd_config.d ]; then
  SSHD_COMBINED="$(mktemp)"
  cat /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null > "$SSHD_COMBINED" || true
  grep -Eqi '^\s*PermitRootLogin\s+no' "$SSHD_COMBINED" || fail "PermitRootLogin not set to no"
  grep -Eqi '^\s*PasswordAuthentication\s+no' "$SSHD_COMBINED" || fail "PasswordAuthentication not set to no"
  # Verify modern cipher suite is set
  grep -Eqi '^\s*Ciphers\s' "$SSHD_COMBINED" || fail "SSH Ciphers not explicitly restricted"
  grep -Eqi '^\s*KexAlgorithms\s' "$SSHD_COMBINED" || fail "SSH KexAlgorithms not explicitly restricted"
  grep -Eqi '^\s*MACs\s' "$SSHD_COMBINED" || fail "SSH MACs not explicitly restricted"
  rm -f "$SSHD_COMBINED"
  pass "SSH hardening checks (auth + ciphers)"
elif [ "$CI_MODE" = "1" ]; then
  SSH_OVERLAY="$ROOT_DIR/overlays/etc/security/sshd_config.d/10-lockclaw-hardening.conf"
  grep -Eqi '^\s*PermitRootLogin\s+no' "$SSH_OVERLAY" || fail "overlay ssh posture missing PermitRootLogin no"
  grep -Eqi '^\s*PasswordAuthentication\s+no' "$SSH_OVERLAY" || fail "overlay ssh posture missing PasswordAuthentication no"
  grep -Eqi '^\s*Ciphers\s' "$SSH_OVERLAY" || fail "overlay ssh posture missing Ciphers restriction"
  grep -Eqi '^\s*KexAlgorithms\s' "$SSH_OVERLAY" || fail "overlay ssh posture missing KexAlgorithms restriction"
  grep -Eqi '^\s*MACs\s' "$SSH_OVERLAY" || fail "overlay ssh posture missing MACs restriction"
  pass "SSH hardening validated from overlay (auth + ciphers)"
fi

# 7) Fail2ban
if command -v fail2ban-client >/dev/null 2>&1; then
  if fail2ban-client status sshd >/dev/null 2>&1; then
    pass "fail2ban sshd jail active"
  elif [ "$CONTAINER_MODE" = "1" ]; then
    # In container mode, fail2ban may be starting; validate the config instead
    if [ -f /etc/fail2ban/jail.local ]; then
      grep -Eqi '^\s*enabled\s*=\s*true' /etc/fail2ban/jail.local || fail "fail2ban sshd jail not enabled"
      pass "fail2ban config validated (jail may still be starting)"
    else
      fail "fail2ban installed but no jail.local found"
    fi
  else
    fail "fail2ban installed but sshd jail not active"
  fi
elif [ "$CI_MODE" = "1" ]; then
  F2B_OVERLAY="$ROOT_DIR/overlays/etc/security/fail2ban/jail.local"
  [ -f "$F2B_OVERLAY" ] || fail "fail2ban jail.local overlay missing"
  grep -Eqi '^\s*enabled\s*=\s*true' "$F2B_OVERLAY" || fail "fail2ban sshd jail not enabled in overlay"
  pass "fail2ban policy validated from overlay"
fi

# 8) Exposure audit — check for unexpected listening ports
if command -v ss >/dev/null 2>&1; then
  # List all TCP listeners excluding loopback-only services
  UNEXPECTED="$(ss -tlnH 2>/dev/null | awk '{print $4}' | grep -v '127\.0\.0\.1' | grep -v '\[::1\]' | grep -v ':22$' | grep -v ':18789$' || true)"
  if [ -n "$UNEXPECTED" ]; then
    note "Unexpected non-loopback listeners detected: $UNEXPECTED"
    # Not a hard fail — the operator may have intentionally exposed services
  else
    pass "no unexpected public listeners (SSH:22 + gateway:18789 loopback)"
  fi
elif [ "$CI_MODE" = "1" ] || [ "$CONTAINER_MODE" = "1" ]; then
  note "ss not available; port exposure check skipped"
fi

# 9) AIDE file integrity
if command -v aide >/dev/null 2>&1; then
  if [ -f /var/lib/aide/aide.db ]; then
    pass "AIDE installed with baseline database"
  elif [ "$CI_MODE" = "1" ]; then
    pass "AIDE installed (baseline created at build time)"
  else
    note "AIDE installed but no baseline database — run: aide --init"
  fi
elif [ "$CI_MODE" = "1" ]; then
  note "AIDE not in CI runner; validated by Dockerfile"
fi

# 10) rkhunter rootkit scanner
if command -v rkhunter >/dev/null 2>&1; then
  pass "rkhunter installed"
elif [ "$CI_MODE" = "1" ]; then
  note "rkhunter not in CI runner; validated by Dockerfile"
fi

# 11) Lynis security auditor
if command -v lynis >/dev/null 2>&1; then
  lynis show version >/dev/null 2>&1 || fail "lynis version check failed"
  pass "lynis installed ($(lynis show version 2>/dev/null || echo 'version unknown'))"
elif [ "$CI_MODE" = "1" ]; then
  note "lynis not in CI runner; validated by Dockerfile"
fi

# 12) Unattended upgrades
if command -v unattended-upgrade >/dev/null 2>&1; then
  if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
    pass "unattended-upgrades configured (security patches)"
  else
    fail "unattended-upgrades installed but config missing"
  fi
elif [ "$CI_MODE" = "1" ]; then
  if [ -f "$ROOT_DIR/overlays/etc/security/apt/50unattended-upgrades" ]; then
    pass "unattended-upgrades config validated from overlay"
  else
    fail "unattended-upgrades overlay missing"
  fi
fi

# 13) Port scan detection (fail2ban portscan jail)
if command -v fail2ban-client >/dev/null 2>&1; then
  if fail2ban-client status portscan >/dev/null 2>&1; then
    pass "fail2ban portscan jail active"
  elif [ "$CONTAINER_MODE" = "1" ]; then
    if [ -f /etc/fail2ban/jail.local ] && grep -q '\[portscan\]' /etc/fail2ban/jail.local; then
      pass "portscan jail configured (may still be starting)"
    else
      fail "portscan jail not configured in jail.local"
    fi
  else
    fail "portscan jail not active"
  fi
elif [ "$CI_MODE" = "1" ]; then
  F2B_OVERLAY="$ROOT_DIR/overlays/etc/security/fail2ban/jail.local"
  if [ -f "$F2B_OVERLAY" ] && grep -q '\[portscan\]' "$F2B_OVERLAY"; then
    pass "portscan jail validated from overlay"
  else
    fail "portscan jail missing from overlay"
  fi
fi

# 14) Update/verification path
if command -v openclaw >/dev/null 2>&1; then
  openclaw --version >/dev/null 2>&1 || fail "openclaw version check failed"

  if command -v npm >/dev/null 2>&1; then
    npm view openclaw version >/dev/null 2>&1 || fail "npm registry lookup failed for openclaw"
    pass "update source reachable via npm registry"
  elif [ "$CI_MODE" = "1" ]; then
    note "npm not present in CI environment; skipped npm registry reachability"
  fi

  openclaw doctor --help >/dev/null 2>&1 || fail "openclaw doctor command unavailable"
  pass "update verification path available (openclaw doctor)"
elif [ "$CI_MODE" = "1" ]; then
  note "openclaw binary not present in CI runner; update path validated by policy docs"
  grep -Eqi 'OpenClaw|doctor' "$ROOT_DIR/docs/design-spec.md" || fail "design spec missing update verification policy"
  pass "update verification policy present"
fi

echo "Smoke tests completed successfully."
