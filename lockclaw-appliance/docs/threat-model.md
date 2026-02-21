# Threat Model — LockClaw Appliance

## What this is

A full OS-level hardened appliance for VMs and bare metal. Every security control is applied at build time.

## Assets

- Host operating system integrity
- SSH access credentials (admin plane)
- AI runtime control plane (loopback-only by design)
- API keys and workspace data
- Audit logs and integrity baselines

## Threats addressed

| Threat | Mitigation | Layer |
|--------|------------|-------|
| Unauthorized remote access | nftables deny-default + SSH key-only + fail2ban | Network + Auth |
| Brute-force SSH | fail2ban (5 attempts → 1hr ban) + nftables rate-limit (4/min) | Auth |
| Port scanning / reconnaissance | nftables log + fail2ban portscan jail (24h ban) | Network |
| File tampering / rootkits | AIDE baseline monitoring + rkhunter scans | Integrity |
| Kernel-level attacks | sysctl hardening (rp_filter, syncookies, ptrace, BPF restricted, sysrq disabled) | Kernel |
| Privilege escalation | auditd watches on passwd/shadow/sudoers, sudo PTY + I/O logging | Audit |
| Weak authentication | Key-only SSH, no root login, modern ciphers, yescrypt password hashing | Auth |
| Unpatched vulnerabilities | unattended-upgrades (Debian security patches daily) | Patching |
| Log tampering | journald persistent + FSS sealing, rsyslog forwarding | Logging |
| DNS hijacking | DNSSEC enforced, explicit resolvers (Cloudflare + Quad9) | Network |
| Unexpected services | Smoke tests hard-fail on non-allowlisted ports | Audit |

## Threats NOT addressed

| Threat | Why | Recommendation |
|--------|-----|----------------|
| Physical access | Cannot control hardware | Physical security controls |
| Zero-day kernel exploits | No preemptive fix possible | Defense-in-depth; monitor Lynis reports |
| Insider with sudo | Legitimate access by design | Review sudo.log; restrict sudoers |
| Supply chain attacks | Mitigated by pinning, not eliminated | Verify upstream SHAs; signed packages |
| Application-level vulns | AI runtimes are separate projects | Keep runtimes updated; sandbox if possible |
| DDoS | Network-level concern | ISP/infrastructure DDoS protection |
| Container escape | This is a VM/bare-metal project | Use lockclaw-baseline in containers |

## Security boundaries

```
┌──────────────────────────────────────────────────────┐
│  Network perimeter (your infrastructure)             │
│  ┌────────────────────────────────────────────────┐  │
│  │  LockClaw Appliance (VM / bare metal)         │  │
│  │                                                │  │
│  │  ┌──────────┐  ┌──────────┐  ┌─────────────┐ │  │
│  │  │ nftables │  │  sshd    │  │  AI Runtime  │ │  │
│  │  │ deny-all │  │  :22     │  │  127.0.0.1   │ │  │
│  │  └──────────┘  └──────────┘  └─────────────┘ │  │
│  │                                                │  │
│  │  auditd + fail2ban + AIDE + rkhunter + Lynis  │  │
│  │  unattended-upgrades                           │  │
│  │  User: lockclaw (sudo, key-auth only)         │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  VPN / Tailscale / private network                   │
└──────────────────────────────────────────────────────┘
```

## Assumptions

1. SSH keys are generated and stored securely by the operator
2. The operator reviews Lynis reports and AIDE change alerts
3. AI runtimes bind to loopback only; access via SSH tunnel or Tailscale
4. The machine is on a private network or behind a VPN for production use
5. Volumes for model data and workspace are on encrypted storage
6. The operator has a process for rotating SSH keys
