#!/usr/bin/env bash
set -euo pipefail

# LockClaw container entrypoint
# Starts hardened services in the correct order

log() { echo "[lockclaw] $*"; }

inject_ssh_key() {
    # Allow operator to inject SSH public key via environment variable
    if [ -n "${SSH_PUBLIC_KEY:-}" ]; then
        mkdir -p /home/lockclaw/.ssh
        echo "$SSH_PUBLIC_KEY" > /home/lockclaw/.ssh/authorized_keys
        chmod 600 /home/lockclaw/.ssh/authorized_keys
        chown -R lockclaw:lockclaw /home/lockclaw/.ssh
        log "SSH public key injected for user 'lockclaw'"
    elif [ -f /home/lockclaw/.ssh/authorized_keys ]; then
        log "SSH authorized_keys found (mounted or pre-existing)"
    else
        log "WARN: No SSH key configured. Set SSH_PUBLIC_KEY env var or mount authorized_keys."
        log "  Example: docker run -e SSH_PUBLIC_KEY=\"\$(cat ~/.ssh/id_ed25519.pub)\" ..."
    fi
}

start_services() {
    log "Starting LockClaw services..."

    # ── Inject SSH key ──
    inject_ssh_key

    # ── Sysctl (requires --privileged or appropriate caps) ──
    if sysctl --system >/dev/null 2>&1; then
        log "Applied sysctl hardening"
    else
        log "WARN: sysctl --system failed (expected in unprivileged containers)"
    fi

    # ── nftables firewall ──
    if command -v nft >/dev/null 2>&1; then
        if nft -f /etc/nftables.conf 2>/dev/null; then
            log "Firewall loaded (deny-by-default)"
        else
            log "WARN: nftables load failed (need --cap-add NET_ADMIN)"
        fi
    fi

    # ── rsyslog ──
    if command -v rsyslogd >/dev/null 2>&1; then
        if rsyslogd 2>/dev/null; then
            log "rsyslog started"
        else
            log "WARN: rsyslog start failed"
        fi
    fi

    # ── auditd ──
    if command -v auditd >/dev/null 2>&1; then
        if auditd 2>/dev/null; then
            log "auditd started"
        else
            log "WARN: auditd failed (need --cap-add AUDIT_WRITE)"
        fi
    fi

    # ── fail2ban ──
    if command -v fail2ban-server >/dev/null 2>&1; then
        if fail2ban-server -b 2>/dev/null; then
            log "fail2ban started (sshd jail)"
        else
            log "WARN: fail2ban start failed"
        fi
    fi

    # ── SSH ──
    if command -v sshd >/dev/null 2>&1; then
        if /usr/sbin/sshd 2>/dev/null; then
            log "sshd started (key-auth only, modern ciphers)"
        else
            log "WARN: sshd start failed"
        fi
    fi

    # ── OpenClaw gateway ──
    if command -v openclaw >/dev/null 2>&1; then
        # Start gateway in background as the lockclaw user
        export HOME=/home/lockclaw
        su lockclaw -c 'openclaw gateway --port 18789 &' 2>/dev/null
        # Give it a moment to bind
        sleep 2
        if ss -tlnH 2>/dev/null | grep -q ':18789'; then
            log "OpenClaw gateway started (ws://127.0.0.1:18789)"
        else
            log "WARN: OpenClaw gateway may still be starting on :18789"
        fi
    fi

    log ""
    log "╔══════════════════════════════════════════════════════════╗"
    log "║  LockClaw ready                                    ║"
    log "║                                                         ║"
    log "║  Admin user:  lockclaw (key-auth only)                  ║"
    log "║  SSH:         port 22 (rate-limited, modern ciphers)    ║"
    log "║  Firewall:    deny-by-default (nftables)                ║"
    log "║  Gateway:     ws://127.0.0.1:18789 (loopback only)     ║"
    log "║  Memory:      claude-mem (persistent across sessions)   ║"
    log "║                                                         ║"
    log "║  Configure:   openclaw onboard                          ║"
    log "║  Validate:    /opt/lockclaw/scripts/test-smoke.sh      ║"
    log "╚══════════════════════════════════════════════════════════╝"
    log ""
}

case "${1:-start}" in
    start)
        start_services
        # Keep container running
        log "LockClaw ready. PID 1 holding."
        exec tail -f /dev/null
        ;;
    test)
        start_services
        exec /opt/lockclaw/scripts/test-smoke.sh
        ;;
    shell)
        start_services
        exec /bin/bash
        ;;
    *)
        exec "$@"
        ;;
esac
