#!/usr/bin/env bash
set -euo pipefail

# LockClaw container entrypoint
# Detects which AI runtime is installed and starts it automatically

log() { echo "[lockclaw] $*"; }

# ── Detect installed runtime ────────────────────────────────
detect_runtime() {
    if command -v openclaw >/dev/null 2>&1; then
        echo "openclaw"
    elif command -v ollama >/dev/null 2>&1; then
        echo "ollama"
    else
        echo "base"
    fi
}

RUNTIME="$(detect_runtime)"

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
        log "WARN: No SSH key configured. Set SSH_PUBLIC_KEY env var or mount authorized_keys."
        log "  Example: docker run -e SSH_PUBLIC_KEY=\"\$(cat ~/.ssh/id_ed25519.pub)\" ..."
    fi
}

start_base_services() {
    log "Starting LockClaw services..."

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
}

start_openclaw() {
    if command -v openclaw >/dev/null 2>&1; then
        export HOME=/home/lockclaw
        su lockclaw -c 'openclaw gateway --port 18789 &' 2>/dev/null
        sleep 2
        if ss -tlnH 2>/dev/null | grep -q ':18789'; then
            log "OpenClaw gateway started (ws://127.0.0.1:18789)"
        else
            log "WARN: OpenClaw gateway may still be starting on :18789"
        fi
    fi
}

start_ollama() {
    if command -v ollama >/dev/null 2>&1; then
        export OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"
        export OLLAMA_MODELS="${OLLAMA_MODELS:-/home/lockclaw/.ollama/models}"
        # Start Ollama server in background
        su lockclaw -c "OLLAMA_HOST=$OLLAMA_HOST OLLAMA_MODELS=$OLLAMA_MODELS ollama serve &" 2>/dev/null
        sleep 2
        if ss -tlnH 2>/dev/null | grep -q ':11434'; then
            log "Ollama started ($OLLAMA_HOST)"
        else
            log "WARN: Ollama may still be starting on $OLLAMA_HOST"
        fi
        log "Pull a model:  ollama pull llama3.2"
        log "Chat:          ollama run llama3.2"
    fi
}

show_banner() {
    log ""
    log "╔══════════════════════════════════════════════════════════╗"
    log "║  LockClaw ready                                    ║"
    log "║                                                         ║"
    log "║  Admin user:  lockclaw (key-auth only)                  ║"
    log "║  SSH:         port 22 (rate-limited, modern ciphers)    ║"
    log "║  Firewall:    deny-by-default (nftables)                ║"

    case "$RUNTIME" in
        openclaw)
            log "║  Runtime:     OpenClaw (ws://127.0.0.1:18789)           ║"
            log "║  Memory:      claude-mem (persistent across sessions)   ║"
            ;;
        ollama)
            log "║  Runtime:     Ollama (http://127.0.0.1:11434)           ║"
            log "║  Models:      /home/lockclaw/.ollama/models             ║"
            ;;
        base)
            log "║  Runtime:     none (bring your own)                     ║"
            ;;
    esac

    log "║  Scanning:    AIDE + rkhunter + Lynis + port-scan det.  ║"
    log "║  Updates:     unattended-upgrades (security patches)    ║"
    log "║                                                         ║"
    log "║  Validate:    /opt/lockclaw/scripts/test-smoke.sh      ║"
    log "║  Scan:        /opt/lockclaw/scripts/security-scan.sh   ║"
    log "╚══════════════════════════════════════════════════════════╝"
    log ""
}

start_services() {
    start_base_services

    case "$RUNTIME" in
        openclaw) start_openclaw ;;
        ollama)   start_ollama ;;
        base)     log "No AI runtime detected — base hardened image" ;;
    esac

    show_banner
}

case "${1:-start}" in
    start)
        start_services
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
