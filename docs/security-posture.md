# Security Posture

## Defaults in this repo
- Kernel hardening via overlays/etc/security/sysctl.conf
- Login/account policy via limits.conf and login.defs
- Sudo policy in overlays/etc/security/sudoers.d/
- SSH hardening in overlays/etc/security/sshd_config.d/
- Audit/logging baselines in overlays/etc/security/audit and logging

## Explicit policy
- SSH is enabled with hardened config (root login and password auth disabled).
- Firewall policy is deny-by-default and should allow only explicitly approved inbound ports.
- OpenClaw gateway should remain loopback-bound by default.

## Operational guidance
- Apply overlays through your image build pipeline
- Validate with scripts/audit.sh and scripts/test-smoke.sh
- Re-run smoke tests after kernel/network/ssh changes
