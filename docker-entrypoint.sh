#!/usr/bin/env bash
set -euo pipefail

# MoltClawLinux container entrypoint
# Starts hardened services in the correct order

log() { echo "[moltclaw] $*"; }

start_services() {
    log "Starting MoltClawLinux services..."

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
            log "WARN: nftables load failed (need NET_ADMIN capability)"
        fi
    fi

    # ── rsyslog ──
    if command -v rsyslogd >/dev/null 2>&1; then
        rsyslogd
        log "rsyslog started"
    fi

    # ── auditd ──
    if command -v auditd >/dev/null 2>&1; then
        # auditd needs AUDIT_WRITE capability
        if auditd -s enable 2>/dev/null || auditd 2>/dev/null; then
            log "auditd started"
        else
            log "WARN: auditd failed (need AUDIT_WRITE capability)"
        fi
    fi

    # ── fail2ban ──
    if command -v fail2ban-server >/dev/null 2>&1; then
        fail2ban-server -b 2>/dev/null || log "WARN: fail2ban start failed"
        log "fail2ban started (sshd jail)"
    fi

    # ── SSH ──
    if command -v sshd >/dev/null 2>&1; then
        /usr/sbin/sshd
        log "sshd started (key-auth only, modern ciphers)"
    fi

    log "All services started."
    log "Exposure: SSH on :22 (hardened), gateway on 127.0.0.1:18789 (loopback)"
    log "Run: docker exec <container> /opt/moltclaw/scripts/test-smoke.sh"
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
