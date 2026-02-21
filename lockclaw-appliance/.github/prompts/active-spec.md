# LockClaw Appliance — Active Spec

> **This file is the phone-to-VSCode bridge.**
> Edit from your phone (via GPT) → push → pull in VS Code → Copilot reads and executes.

## Project summary

LockClaw Appliance is a hardened Linux appliance for self-hosting AI runtimes
on VMs and bare metal. It enforces deny-by-default security at the OS level:
nftables firewall, auditd, fail2ban, AIDE, rkhunter, Lynis, SSH hardening,
kernel sysctl hardening, and automated security patching.

## Architecture

```
overlays/etc/security/ ← kernel, SSH, sudo, audit, fail2ban, logging policy
overlays/etc/network/  ← nftables firewall, resolver, NTP
packages/              ← OS-level package manifests
scripts/               ← build, smoke test, audit tooling
lockclaw-core/         ← shared audit scripts and port allowlists (vendored)
image-builder/         ← VM artifact pipeline (ISO/qcow2/raw)
docs/                  ← threat model, security posture, networking posture
```

## Security model

- Deny-all inbound (nftables). Allow SSH (rate-limited), loopback, DHCP, established.
- SSH: key-only, no root, modern ciphers, MaxAuthTries 3.
- fail2ban: 5 failures → 1h ban; port scan → 24h ban.
- AIDE: file integrity baseline. rkhunter: rootkit detection.
- auditd: monitors passwd, shadow, sudoers, sshd_config, privilege binaries.
- Kernel: rp_filter, syncookies, no ICMP redirects, ptrace restricted.

## Current task

TASK_START
[READY FOR NEXT VIBE]
TASK_END

## History

HISTORY_START
HISTORY_END
