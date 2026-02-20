#!/usr/bin/env bash
set -euo pipefail

# MoltClawLinux container entrypoint
# Starts hardened services in the correct order

log() { echo "[moltclaw] $*"; }

inject_ssh_key() {
    # Allow operator to inject SSH public key via environment variable
    if [ -n "${SSH_PUBLIC_KEY:-}" ]; then
        mkdir -p /home/moltclaw/.ssh
        echo "$SSH_PUBLIC_KEY" > /home/moltclaw/.ssh/authorized_keys
        chmod 600 /home/moltclaw/.ssh/authorized_keys
        chown -R moltclaw:moltclaw /home/moltclaw/.ssh
        log "SSH public key injected for user 'moltclaw'"
    elif [ -f /home/moltclaw/.ssh/authorized_keys ]; then
        log "SSH authorized_keys found (mounted or pre-existing)"
    else
        log "WARN: No SSH key configured. Set SSH_PUBLIC_KEY env var or mount authorized_keys."
        log "  Example: docker run -e SSH_PUBLIC_KEY=\"\$(cat ~/.ssh/id_ed25519.pub)\" ..."
    fi
}

start_services() {
    log "Starting MoltClawLinux services..."

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

    log ""
    log "╔══════════════════════════════════════════════════════════╗"
    log "║  MoltClawLinux ready                                    ║"
    log "║                                                         ║"
    log "║  Admin user:  moltclaw (key-auth only)                  ║"
    log "║  SSH:         port 22 (rate-limited, modern ciphers)    ║"
    log "║  Firewall:    deny-by-default (nftables)                ║"
    log "║  Gateway:     127.0.0.1:18789 (loopback only)          ║"
    log "║                                                         ║"
    log "║  Validate:    /opt/moltclaw/scripts/test-smoke.sh      ║"
    log "╚══════════════════════════════════════════════════════════╝"
    log ""
}

case "${1:-start}" in
    start)
        start_services
        # Keep container running
        log "MoltClawLinux ready. PID 1 holding."
        exec tail -f /dev/null
        ;;
    test)
        start_services
        exec /opt/moltclaw/scripts/test-smoke.sh
        ;;
    shell)
        start_services
        exec /bin/bash
        ;;
    *)
        exec "$@"
        ;;
esac
