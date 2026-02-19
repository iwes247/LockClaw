# Security Posture

## Defaults in this repo
- Kernel hardening via overlays/etc/security/sysctl.conf (rp_filter, syncookies, ICMP, ptrace, BPF, sysrq, fs protections)
- Login/account policy via limits.conf and login.defs (yescrypt password hashing)
- Sudo policy in overlays/etc/security/sudoers.d/ (use_pty, I/O logging, 5-min timeout)
- SSH hardening in overlays/etc/security/sshd_config.d/ (no root, no password, modern ciphers + KEX + MACs only)
- Brute-force protection via overlays/etc/security/fail2ban/jail.local (sshd jail, 5 attempts → 1hr ban)
- Audit/logging baselines in overlays/etc/security/audit, logging, and rsyslog.d
- Log rotation for sudo audit log via overlays/etc/security/logrotate.d/sudo

## Explicit policy
- SSH is enabled with hardened config (root login and password auth disabled; ciphers restricted to chacha20-poly1305, aes256-gcm, aes128-gcm).
- Firewall policy is deny-by-default via nftables ruleset (overlays/etc/network/nftables.conf). Only SSH:22 (rate-limited), DHCP, loopback, and established/related traffic is allowed inbound.
- OpenClaw gateway should remain loopback-bound by default.
- Brute-force attempts on SSH are mitigated by both nftables rate-limiting and fail2ban jail.

## Operational guidance
- Apply overlays through your image build pipeline
- Validate with scripts/audit.sh and scripts/test-smoke.sh
- Re-run smoke tests after kernel/network/ssh changes
