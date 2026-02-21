# LockClaw Appliance — Hardened OS for AI runtimes
# Full OS-level hardening for VM/bare-metal deployments via ISO/qcow2/raw.
#
# This Dockerfile is for development and testing of the appliance image.
# Production artifacts are built via image-builder/ (ISO, qcow2, raw).
#
# Build (for testing):
#   docker build -t lockclaw-appliance:test .
#
# Run (for testing — requires elevated capabilities):
#   docker run -d --name lockclaw-appliance \
#     --cap-add NET_ADMIN \
#     --cap-add AUDIT_WRITE \
#     -e SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
#     -p 2222:22 lockclaw-appliance:test

FROM debian:bookworm-slim

LABEL maintainer="iwes247"
LABEL org.opencontainers.image.title="LockClaw Appliance"
LABEL org.opencontainers.image.description="Hardened Linux appliance for self-hosting AI runtimes"
LABEL org.opencontainers.image.source="https://github.com/iwes247/lockclaw-appliance"

# ── Environment ──────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive
ENV LOCKCLAW_HOME=/opt/lockclaw

# ── Install OS packages ─────────────────────────────────────
COPY packages/security-defaults.txt /tmp/security-defaults.txt
COPY packages/network-defaults.txt  /tmp/network-defaults.txt

RUN apt-get update && \
    grep -hv '^\s*#\|^\s*$' \
      /tmp/security-defaults.txt \
      /tmp/network-defaults.txt \
      | xargs apt-get install -y --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/*.txt

# ── Create directories needed by overlays ────────────────────
RUN mkdir -p \
      /etc/sysctl.d \
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
COPY overlays/etc/security/rkhunter/rkhunter.conf.local \
                                                /etc/rkhunter.conf.d/lockclaw.conf
COPY overlays/etc/security/apt/50unattended-upgrades \
                                                /etc/apt/apt.conf.d/50unattended-upgrades
COPY overlays/etc/security/apt/20auto-upgrades  /etc/apt/apt.conf.d/20auto-upgrades

# ── Apply network overlays ──────────────────────────────────
COPY overlays/etc/network/nftables.conf         /etc/nftables.conf

# ── Apply login.defs overrides ───────────────────────────────
RUN if [ -f /etc/login.defs ]; then \
      sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD yescrypt/' /etc/login.defs && \
      sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs && \
      sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/' /etc/login.defs && \
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

# ── Copy tooling into the image ──────────────────────────────
COPY scripts/        ${LOCKCLAW_HOME}/scripts/
COPY lockclaw-core/  ${LOCKCLAW_HOME}/lockclaw-core/
COPY overlays/       ${LOCKCLAW_HOME}/overlays/
COPY packages/       ${LOCKCLAW_HOME}/packages/
COPY docs/           ${LOCKCLAW_HOME}/docs/
RUN chmod +x ${LOCKCLAW_HOME}/scripts/*.sh \
             ${LOCKCLAW_HOME}/lockclaw-core/audit/*.sh \
             ${LOCKCLAW_HOME}/lockclaw-core/scanner/*.sh

# ── Entrypoint ───────────────────────────────────────────────
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 22

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD pgrep -x sshd > /dev/null || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["start"]
