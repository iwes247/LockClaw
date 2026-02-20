# LockClaw — Hardened container image
# Security-hardened OS layer for self-hosting AI runtimes
#
# Targets:
#   base     — hardened OS only (bring your own runtime)
#   openclaw — base + OpenClaw gateway + claude-mem
#   ollama   — base + Ollama for local LLM inference
#
# Build:
#   docker build --target base     -t lockclaw:base .
#   docker build --target openclaw -t lockclaw:openclaw .
#   docker build --target ollama   -t lockclaw:ollama .
#   docker build -t lockclaw:latest .       # defaults to openclaw
#
# Run:
#   docker run -d --name lockclaw --cap-add NET_ADMIN --cap-add AUDIT_WRITE -p 2222:22 lockclaw:latest
# Test:
#   docker exec lockclaw /opt/lockclaw/scripts/test-smoke.sh

# ═════════════════════════════════════════════════════════════
# Stage 1: BASE — Hardened OS with no AI runtime
# ═════════════════════════════════════════════════════════════
FROM debian:bookworm-slim AS base

LABEL maintainer="iwes247"
LABEL org.opencontainers.image.title="LockClaw"
LABEL org.opencontainers.image.description="Hardened Linux layer for self-hosting AI runtimes"

# ── Environment ──────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive
ENV LOCKCLAW_HOME=/opt/lockclaw

# ── Install OS packages ─────────────────────────────────────
COPY packages/security-defaults.txt /tmp/security-defaults.txt
COPY packages/network-defaults.txt  /tmp/network-defaults.txt

RUN apt-get update && \
    grep -hv '^\s*#\|^\s*$' /tmp/security-defaults.txt /tmp/network-defaults.txt \
      | xargs apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*.txt

# ── Create directories needed by overlays ────────────────────
RUN mkdir -p /etc/sysctl.d \
             /etc/security \
             /etc/ssh/sshd_config.d \
             /etc/sudoers.d \
             /etc/audit/rules.d \
             /etc/systemd/journald.conf.d \
             /etc/rsyslog.d \
             /etc/logrotate.d \
             /etc/fail2ban/filter.d \
             /etc/aide \
             /etc/rkhunter.conf.d \
             /etc/apt/apt.conf.d \
             /var/lib/aide \
             /var/log/journal \
             /run/sshd

# ── Apply security overlays ─────────────────────────────────
COPY overlays/etc/security/sysctl.conf          /etc/sysctl.d/99-lockclaw.conf
COPY overlays/etc/security/limits.conf          /etc/security/limits.d/99-lockclaw.conf
COPY overlays/etc/security/sudoers.d/           /etc/sudoers.d/
COPY overlays/etc/security/sshd_config.d/       /etc/ssh/sshd_config.d/
COPY overlays/etc/security/audit/audit.rules    /etc/audit/rules.d/99-lockclaw.rules
COPY overlays/etc/security/logging/journald.conf /etc/systemd/journald.conf.d/99-lockclaw.conf
COPY overlays/etc/security/fail2ban/jail.local  /etc/fail2ban/jail.local
COPY overlays/etc/security/fail2ban/filter.d/   /etc/fail2ban/filter.d/
COPY overlays/etc/security/rsyslog.d/           /etc/rsyslog.d/
COPY overlays/etc/security/logrotate.d/sudo     /etc/logrotate.d/sudo
COPY overlays/etc/security/aide/aide.conf       /etc/aide/aide.conf
COPY overlays/etc/security/rkhunter/rkhunter.conf.local /etc/rkhunter.conf.d/lockclaw.conf
COPY overlays/etc/security/apt/50unattended-upgrades    /etc/apt/apt.conf.d/50unattended-upgrades
COPY overlays/etc/security/apt/20auto-upgrades          /etc/apt/apt.conf.d/20auto-upgrades

# ── Apply network overlays ──────────────────────────────────
COPY overlays/etc/network/nftables.conf         /etc/nftables.conf

# ── Apply login.defs overrides ───────────────────────────────
RUN if [ -f /etc/login.defs ]; then \
      sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD yescrypt/' /etc/login.defs; \
      sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs; \
      sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/' /etc/login.defs; \
      sed -i 's/^UMASK.*/UMASK 027/' /etc/login.defs; \
    fi

# ── Set correct permissions on security files ────────────────
RUN chmod 0440 /etc/sudoers.d/* && \
    chmod 0600 /etc/ssh/sshd_config.d/* && \
    chmod 0640 /etc/audit/rules.d/* && \
    chmod 0644 /etc/nftables.conf && \
    chmod 0644 /etc/fail2ban/jail.local && \
    chmod 0644 /etc/logrotate.d/sudo && \
    chmod 0600 /etc/aide/aide.conf && \
    chmod 0644 /etc/apt/apt.conf.d/50unattended-upgrades && \
    chmod 0644 /etc/apt/apt.conf.d/20auto-upgrades

# ── SSH host keys ────────────────────────────────────────────
RUN ssh-keygen -A

# ── Initialise AIDE baseline ─────────────────────────────────
RUN aide --init --config /etc/aide/aide.conf && \
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# ── Initialise rkhunter baseline ─────────────────────────────
RUN rkhunter --propupd --nocolors 2>/dev/null || true

# ── Create admin user ────────────────────────────────────────
RUN useradd -m -s /bin/bash -G sudo lockclaw && \
    mkdir -p /home/lockclaw/.ssh && \
    chmod 700 /home/lockclaw/.ssh && \
    chown -R lockclaw:lockclaw /home/lockclaw/.ssh && \
    passwd -l lockclaw

# ── Copy LockClaw repo tooling into the image ───────────
COPY scripts/  ${LOCKCLAW_HOME}/scripts/
COPY docs/     ${LOCKCLAW_HOME}/docs/
COPY packages/ ${LOCKCLAW_HOME}/packages/
COPY overlays/ ${LOCKCLAW_HOME}/overlays/
RUN chmod +x ${LOCKCLAW_HOME}/scripts/*.sh

# ── Entrypoint ───────────────────────────────────────────────
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 22

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["start"]


# ═════════════════════════════════════════════════════════════
# Stage 2: OPENCLAW — OpenClaw gateway + claude-mem
# ═════════════════════════════════════════════════════════════
FROM base AS openclaw

LABEL org.opencontainers.image.description="LockClaw + OpenClaw AI gateway + claude-mem"

# ── Install Node.js 22 ──────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates gnupg git && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Install OpenClaw gateway ─────────────────────────────────
RUN npm install -g openclaw@latest && \
    npm cache clean --force

# ── Configure OpenClaw workspace ─────────────────────────────
RUN mkdir -p /home/lockclaw/.openclaw/workspace/skills && \
    echo '{"gateway":{"port":18789,"bind":"loopback"},"agent":{"model":"anthropic/claude-opus-4-6"}}' \
      > /home/lockclaw/.openclaw/openclaw.json && \
    chown -R lockclaw:lockclaw /home/lockclaw/.openclaw

# ── Pre-install claude-mem plugin ────────────────────────────
RUN npm install -g claude-mem@latest && \
    npm cache clean --force

EXPOSE 18789


# ═════════════════════════════════════════════════════════════
# Stage 3: OLLAMA — Local LLM inference engine
# ═════════════════════════════════════════════════════════════
FROM base AS ollama

LABEL org.opencontainers.image.description="LockClaw + Ollama local LLM engine"

# ── Install Ollama ───────────────────────────────────────────
# The official install script downloads the correct binary for the arch
# and places it in /usr/local/bin. The systemd service setup will fail
# in Docker (no systemd) but the binary is still installed.
# Requires ca-certificates (added to network-defaults.txt).
RUN curl -fsSL https://ollama.com/install.sh | sh || true && \
    command -v ollama && \
    ollama --version

# ── Configure Ollama for loopback-only ───────────────────────
# Bind to loopback so the API is never directly exposed — same approach
# as the OpenClaw gateway. Access via SSH tunnel.
ENV OLLAMA_HOST=127.0.0.1:11434
ENV OLLAMA_MODELS=/home/lockclaw/.ollama/models

# ── Create Ollama dirs with correct ownership ────────────────
RUN mkdir -p /home/lockclaw/.ollama/models && \
    chown -R lockclaw:lockclaw /home/lockclaw/.ollama

EXPOSE 11434
