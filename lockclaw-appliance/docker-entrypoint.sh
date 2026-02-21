#!/usr/bin/env bash
set -euo pipefail

# LockClaw Appliance — entrypoint
# Full OS-level hardening services: nftables, auditd, fail2ban, sshd.
# For VM/bare-metal deployments (or testing with --cap-add NET_ADMIN AUDIT_WRITE).

log() { echo "[lockclaw] $*"; }

inject_ssh_key() {
    if [ -n "${SSH_PUBLIC_KEY:-}" ]; then
        mkdir -p /home/lockclaw/.ssh
        echo "$SSH_PUBLIC_KEY" > /home/lockclaw/.ssh/authorized_keys
        chmod 600 /home/lockclaw/.ssh/authorized_keys
        chown -R lockclaw:lockclaw /home/lockclaw/.ssh
        log "SSH public key injected for user 'lockclaw'"
    elif [ -f /home/lockclaw/.ssh/authorized_keys ]; then
        log "SSH authorized_keys found (mounted or pre-existing)"
    else
        log "WARN: No SSH key configured."
        log "  Set SSH_PUBLIC_KEY env var or mount authorized_keys."
        log "  Example: docker run -e SSH_PUBLIC_KEY=\"\$(cat ~/.ssh/id_ed25519.pub)\" ..."
    fi
}

start_services() {
    log "Starting LockClaw Appliance services..."

    inject_ssh_key

    # ── Sysctl ──
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
            log "fail2ban started (sshd + portscan jails)"
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

    show_banner
}

show_banner() {
    log ""
    log "╔══════════════════════════════════════════════════════════╗"
    log "║  LockClaw Appliance ready                               ║"
    log "║                                                         ║"
    log "║  Admin user:  lockclaw (key-auth only)                  ║"
    log "║  SSH:         port 22 (rate-limited, modern ciphers)    ║"
    log "║  Firewall:    deny-by-default (nftables)                ║"
    log "║  Scanning:    AIDE + rkhunter + Lynis                   ║"
    log "║  Updates:     unattended-upgrades (security patches)    ║"
    log "║                                                         ║"
    log "║  Validate:    /opt/lockclaw/scripts/test-smoke.sh       ║"
    log "║  Scan:        /opt/lockclaw/lockclaw-core/scanner/security-scan.sh ║"
    log "╚══════════════════════════════════════════════════════════╝"
    log ""
}

case "${1:-start}" in
    start)
        start_services
        log "LockClaw Appliance ready. PID 1 holding."
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
