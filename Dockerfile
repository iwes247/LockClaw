# MoltClawLinux — Hardened container image
# Secure-by-default OS layer for OpenClaw gateway hosting
#
# Build:  docker build -t moltclaw:latest .
# Run:    docker run -d --name moltclaw --cap-add NET_ADMIN --cap-add AUDIT_WRITE -p 2222:22 moltclaw:latest
# Shell:  docker exec -it moltclaw bash
# Test:   docker exec moltclaw /opt/moltclaw/scripts/test-smoke.sh

FROM debian:bookworm-slim AS base

LABEL maintainer="iwes247"
LABEL org.opencontainers.image.title="MoltClawLinux"
LABEL org.opencontainers.image.description="Hardened Linux layer for OpenClaw gateway hosting"

# ── Environment ──────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive
ENV MOLTCLAW_HOME=/opt/moltclaw

# ── Install OS packages ─────────────────────────────────────
# Two-phase: copy manifests first for layer caching, then install
COPY packages/security-defaults.txt /tmp/security-defaults.txt
COPY packages/network-defaults.txt  /tmp/network-defaults.txt

RUN apt-get update && \
    # Parse package names from manifests (skip comments and blanks)
    grep -hv '^\s*#\|^\s*$' /tmp/security-defaults.txt /tmp/network-defaults.txt \
      | xargs apt-get install -y --no-install-recommends && \
    # Clean up apt cache to keep image small
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*.txt

# ── Install Node.js 22 (OpenClaw runtime) ───────────────────
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

# ── Create directories needed by overlays ────────────────────
# Must exist before COPY targets them
RUN mkdir -p /etc/sysctl.d \
             /etc/security \
             /etc/ssh/sshd_config.d \
             /etc/sudoers.d \
             /etc/audit/rules.d \
             /etc/systemd/journald.conf.d \
             /etc/rsyslog.d \
             /etc/logrotate.d \
             /etc/fail2ban \
             /var/log/journal \
             /run/sshd

# ── Apply security overlays ─────────────────────────────────
COPY overlays/etc/security/sysctl.conf          /etc/sysctl.d/99-moltclaw.conf
COPY overlays/etc/security/limits.conf          /etc/security/limits.d/99-moltclaw.conf
COPY overlays/etc/security/sudoers.d/           /etc/sudoers.d/
COPY overlays/etc/security/sshd_config.d/       /etc/ssh/sshd_config.d/
COPY overlays/etc/security/audit/audit.rules    /etc/audit/rules.d/99-moltclaw.rules
COPY overlays/etc/security/logging/journald.conf /etc/systemd/journald.conf.d/99-moltclaw.conf
COPY overlays/etc/security/fail2ban/jail.local  /etc/fail2ban/jail.local
COPY overlays/etc/security/rsyslog.d/           /etc/rsyslog.d/
COPY overlays/etc/security/logrotate.d/sudo     /etc/logrotate.d/sudo

# ── Apply network overlays ──────────────────────────────────
# NetworkManager, resolved, timesyncd — not used in container mode
# Their overlays remain in the repo for bare-metal/VM targets
COPY overlays/etc/network/nftables.conf         /etc/nftables.conf

# ── Apply login.defs overrides ───────────────────────────────
# login.defs doesn't support .d/ drop-ins; patch in-place
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
    chmod 0644 /etc/logrotate.d/sudo

# ── SSH host keys ────────────────────────────────────────────
# Generate at build time so the image is ready to accept connections
RUN ssh-keygen -A

# ── Create admin user ────────────────────────────────────────
# Root login is disabled by SSH policy. This is the admin account.
# The operator must inject their public key at runtime.
RUN useradd -m -s /bin/bash -G sudo moltclaw && \
    mkdir -p /home/moltclaw/.ssh && \
    chmod 700 /home/moltclaw/.ssh && \
    chown -R moltclaw:moltclaw /home/moltclaw/.ssh && \
    # Lock password (key-only auth enforced by sshd_config)
    passwd -l moltclaw

# ── Configure OpenClaw workspace ─────────────────────────────
# Minimal config: model set via env var at runtime, gateway on loopback
RUN mkdir -p /home/moltclaw/.openclaw/workspace/skills && \
    echo '{"gateway":{"port":18789,"bind":"loopback"},"agent":{"model":"anthropic/claude-opus-4-6"}}' \
      > /home/moltclaw/.openclaw/openclaw.json && \
    chown -R moltclaw:moltclaw /home/moltclaw/.openclaw

# ── Pre-install claude-mem plugin ────────────────────────────
# Persistent memory across sessions — the killer feature for self-hosted AI
RUN npm install -g claude-mem@latest && \
    npm cache clean --force

# ── Copy MoltClawLinux repo tooling into the image ───────────
COPY scripts/  ${MOLTCLAW_HOME}/scripts/
COPY docs/     ${MOLTCLAW_HOME}/docs/
COPY packages/ ${MOLTCLAW_HOME}/packages/
COPY overlays/ ${MOLTCLAW_HOME}/overlays/
RUN chmod +x ${MOLTCLAW_HOME}/scripts/*.sh

# ── Entrypoint ───────────────────────────────────────────────
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 22 18789

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["start"]
