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

# ── Apply security overlays ─────────────────────────────────
COPY overlays/etc/security/sysctl.conf          /etc/sysctl.d/99-moltclaw.conf
COPY overlays/etc/security/limits.conf          /etc/security/limits.d/99-moltclaw.conf
COPY overlays/etc/security/login.defs           /etc/login.defs.d/moltclaw
COPY overlays/etc/security/sudoers.d/           /etc/sudoers.d/
COPY overlays/etc/security/sshd_config.d/       /etc/ssh/sshd_config.d/
COPY overlays/etc/security/audit/audit.rules    /etc/audit/rules.d/99-moltclaw.rules
COPY overlays/etc/security/logging/journald.conf /etc/systemd/journald.conf.d/99-moltclaw.conf
COPY overlays/etc/security/fail2ban/jail.local  /etc/fail2ban/jail.local
COPY overlays/etc/security/rsyslog.d/           /etc/rsyslog.d/
COPY overlays/etc/security/logrotate.d/sudo     /etc/logrotate.d/sudo

# ── Apply network overlays ──────────────────────────────────
COPY overlays/etc/network/NetworkManager.conf   /etc/NetworkManager/conf.d/99-moltclaw.conf
COPY overlays/etc/network/resolved.conf         /etc/systemd/resolved.conf.d/99-moltclaw.conf
COPY overlays/etc/network/timesyncd.conf        /etc/systemd/timesyncd.conf.d/99-moltclaw.conf
COPY overlays/etc/network/nftables.conf         /etc/nftables.conf

# ── Apply login.defs overrides ───────────────────────────────
# login.defs doesn't support .d/ drop-ins; patch in-place
RUN if [ -f /etc/login.defs ]; then \
      sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD yescrypt/' /etc/login.defs; \
      sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs; \
      sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/' /etc/login.defs; \
      sed -i 's/^UMASK.*/UMASK 027/' /etc/login.defs; \
    fi && \
    rm -f /etc/login.defs.d/moltclaw

# ── Create drop-in directories if missing ────────────────────
RUN mkdir -p /etc/systemd/journald.conf.d \
             /etc/systemd/resolved.conf.d \
             /etc/systemd/timesyncd.conf.d \
             /etc/NetworkManager/conf.d \
             /etc/audit/rules.d \
             /var/log/journal \
             /run/sshd

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

# ── Copy MoltClawLinux repo tooling into the image ───────────
COPY scripts/  ${MOLTCLAW_HOME}/scripts/
COPY docs/     ${MOLTCLAW_HOME}/docs/
COPY packages/ ${MOLTCLAW_HOME}/packages/
COPY overlays/ ${MOLTCLAW_HOME}/overlays/
RUN chmod +x ${MOLTCLAW_HOME}/scripts/*.sh

# ── Entrypoint ───────────────────────────────────────────────
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 22

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["start"]
