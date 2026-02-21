#!/usr/bin/env bash
set -euo pipefail

# LockClaw Appliance — smoke tests
# Full OS-level checks: firewall, SSH hardening, auditd, fail2ban, AIDE, etc.
# Designed for VM/bare-metal or testing in Docker with elevated capabilities.

fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "PASS: $*"; }
note() { echo "NOTE: $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Detect container mode
CONTAINER_MODE=0
if [ -f /.dockerenv ] || grep -qsE ':/docker/|:/lxc/' /proc/1/cgroup 2>/dev/null; then
    CONTAINER_MODE=1
fi

# ── 1) Boot check ───────────────────────────────────────────
if [ -r /proc/uptime ]; then
    awk '{ if ($1 > 0) exit 0; exit 1 }' /proc/uptime || fail "uptime invalid"
    pass "system running"
else
    fail "cannot verify system state"
fi

# ── 2) Firewall ─────────────────────────────────────────────
if command -v nft >/dev/null 2>&1; then
    if nft list ruleset >/dev/null 2>&1; then
        RULESET="$(nft list ruleset 2>/dev/null)"
        if echo "$RULESET" | grep -q 'policy drop'; then
            pass "nftables loaded with deny-default policy"
        elif [ "$CONTAINER_MODE" = "1" ]; then
            if [ -f /etc/nftables.conf ] && grep -q 'policy drop' /etc/nftables.conf; then
                pass "nftables config has deny-default (kernel may limit visibility)"
            else
                fail "nftables loaded but no deny-default policy"
            fi
        else
            fail "nftables: input policy is not drop"
        fi
    elif [ "$CONTAINER_MODE" = "1" ]; then
        if [ -f /etc/nftables.conf ] && grep -q 'policy drop' /etc/nftables.conf; then
            pass "nftables config validated (may need --cap-add NET_ADMIN)"
        else
            fail "nftables not readable and no config found"
        fi
    else
        fail "nftables not readable"
    fi
else
    fail "nft command not found"
fi

# ── 3) SSH hardening ────────────────────────────────────────
if [ -f /etc/ssh/sshd_config ] || [ -d /etc/ssh/sshd_config.d ]; then
    SSHD_COMBINED="$(mktemp)"
    cat /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null > "$SSHD_COMBINED" || true

    grep -Eqi '^\s*PermitRootLogin\s+no' "$SSHD_COMBINED" \
        || fail "PermitRootLogin not set to no"
    grep -Eqi '^\s*PasswordAuthentication\s+no' "$SSHD_COMBINED" \
        || fail "PasswordAuthentication not set to no"
    grep -Eqi '^\s*Ciphers\s' "$SSHD_COMBINED" \
        || fail "SSH Ciphers not explicitly restricted"
    grep -Eqi '^\s*KexAlgorithms\s' "$SSHD_COMBINED" \
        || fail "SSH KexAlgorithms not explicitly restricted"
    grep -Eqi '^\s*MACs\s' "$SSHD_COMBINED" \
        || fail "SSH MACs not explicitly restricted"

    rm -f "$SSHD_COMBINED"
    pass "SSH hardening checks (auth + ciphers)"
else
    fail "SSH config not found"
fi

# ── 4) SSH listening ────────────────────────────────────────
if command -v ss >/dev/null 2>&1; then
    if ss -ltn | grep -q ':22'; then
        pass "sshd listening on port 22"
    elif [ "$CONTAINER_MODE" = "1" ]; then
        note "sshd not listening yet (container startup)"
    else
        fail "sshd not listening on 22"
    fi
fi

# ── 5) fail2ban ─────────────────────────────────────────────
if command -v fail2ban-client >/dev/null 2>&1; then
    if fail2ban-client status sshd >/dev/null 2>&1; then
        pass "fail2ban sshd jail active"
    elif [ "$CONTAINER_MODE" = "1" ]; then
        if [ -f /etc/fail2ban/jail.local ]; then
            grep -Eqi '^\s*enabled\s*=\s*true' /etc/fail2ban/jail.local \
                || fail "fail2ban sshd jail not enabled"
            pass "fail2ban config validated (jail may still be starting)"
        else
            fail "fail2ban installed but no jail.local"
        fi
    else
        fail "fail2ban sshd jail not active"
    fi
else
    fail "fail2ban not installed"
fi

# ── 6) AIDE ─────────────────────────────────────────────────
if command -v aide >/dev/null 2>&1; then
    if [ -f /var/lib/aide/aide.db ]; then
        pass "AIDE installed with baseline database"
    else
        note "AIDE installed but no baseline — run: aide --init"
    fi
else
    fail "AIDE not installed"
fi

# ── 7) rkhunter ─────────────────────────────────────────────
if command -v rkhunter >/dev/null 2>&1; then
    pass "rkhunter installed"
else
    fail "rkhunter not installed"
fi

# ── 8) Lynis ────────────────────────────────────────────────
if command -v lynis >/dev/null 2>&1; then
    lynis show version >/dev/null 2>&1 || fail "lynis version check failed"
    pass "lynis installed ($(lynis show version 2>/dev/null || echo 'unknown'))"
else
    fail "lynis not installed"
fi

# ── 9) Unattended upgrades ──────────────────────────────────
if command -v unattended-upgrade >/dev/null 2>&1; then
    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
        pass "unattended-upgrades configured"
    else
        fail "unattended-upgrades installed but config missing"
    fi
else
    fail "unattended-upgrades not installed"
fi

# ── 10) Port exposure audit ─────────────────────────────────
if command -v ss >/dev/null 2>&1; then
    echo ""
    echo "=== Port Exposure Audit ==="

    UNEXPECTED=$(
        ss -tlnH 2>/dev/null \
        | awk '{print $4}' \
        | grep -v '127\.0\.0\.1' \
        | grep -v '\[::1\]' \
        | grep -v ':22$' \
        || true
    )

    if [ -n "$UNEXPECTED" ]; then
        echo "UNEXPECTED non-loopback listeners: $UNEXPECTED"
        fail "unexpected ports exposed"
    else
        pass "no unexpected public listeners (SSH:22 only)"
    fi
fi

# ── 11) Portscan jail ───────────────────────────────────────
if command -v fail2ban-client >/dev/null 2>&1; then
    if fail2ban-client status portscan >/dev/null 2>&1; then
        pass "fail2ban portscan jail active"
    elif [ "$CONTAINER_MODE" = "1" ]; then
        if [ -f /etc/fail2ban/jail.local ] && grep -q '\[portscan\]' /etc/fail2ban/jail.local; then
            pass "portscan jail configured (may still be starting)"
        else
            fail "portscan jail not configured"
        fi
    else
        fail "portscan jail not active"
    fi
fi

# ── 12) DNS ─────────────────────────────────────────────────
if command -v getent >/dev/null 2>&1; then
    if getent hosts github.com >/dev/null 2>&1; then
        pass "DNS resolution"
    else
        note "DNS resolution failed"
    fi
fi

echo ""
echo "Appliance smoke tests completed."
