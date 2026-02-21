# LockClaw Appliance

Hardened Linux appliance for self-hosting AI runtimes on VMs and bare metal.

## Who it's for

Operators deploying AI runtimes on VPSes, homelab servers, or bare-metal machines who want OS-level hardening applied at build time — not as an afterthought.

## What it is NOT

- **Not a Docker deployment tool.** For containers, use [lockclaw-baseline](https://github.com/iwes247/lockclaw-baseline).
- **Not a general-purpose Linux distro.** This is a single-purpose appliance image with an opinionated security posture.
- **Not optional hardening.** Security policy is applied at build time. You cannot "turn it off" without rebuilding.

## What it does

| Layer | What it does | Config |
|-------|-------------|--------|
| Firewall | nftables drops all inbound; allows SSH (rate-limited), loopback, DHCP, established/related | `overlays/etc/network/nftables.conf` |
| SSH | Key-only auth, no root login, modern ciphers (chacha20-poly1305, aes256-gcm), MaxAuthTries 3 | `overlays/etc/security/sshd_config.d/` |
| Brute-force | fail2ban bans IPs after 5 failed SSH attempts for 1 hour | `overlays/etc/security/fail2ban/jail.local` |
| Port scanning | nftables logs dropped packets; fail2ban auto-bans scanners for 24h | `overlays/etc/security/fail2ban/filter.d/portscan.conf` |
| File integrity | AIDE monitors critical binaries and configs against a build-time baseline | `overlays/etc/security/aide/aide.conf` |
| Rootkit detection | rkhunter scans for known rootkits, backdoors, suspicious files | `overlays/etc/security/rkhunter/` |
| Security audit | Lynis comprehensive hardening checks with scored report | On-demand: `lynis audit system --quick` |
| Auto updates | unattended-upgrades applies Debian security patches daily | `overlays/etc/security/apt/` |
| Kernel hardening | rp_filter, syncookies, no ICMP redirects, no source routing, ptrace restricted, BPF restricted, sysrq disabled | `overlays/etc/security/sysctl.conf` |
| Accounts | yescrypt password hashing, 90-day rotation, umask 027 | `overlays/etc/security/login.defs` |
| Sudo | PTY required, full I/O logging to `/var/log/sudo.log`, 5-minute credential timeout | `overlays/etc/security/sudoers.d/` |
| Audit | auditd watches passwd, shadow, sudoers, sshd_config, nftables, privilege escalation binaries | `overlays/etc/security/audit/audit.rules` |
| Logging | journald persistent + FSS sealing, rsyslog auth/kern/daemon, logrotate on sudo.log | `overlays/etc/security/logging/` |

## Quickstart

### Build and test (Docker — for development)

```bash
git clone https://github.com/iwes247/lockclaw-appliance.git && cd lockclaw-appliance

docker build -t lockclaw-appliance:test .

docker run -d --name lockclaw-appliance \
  --cap-add NET_ADMIN \
  --cap-add AUDIT_WRITE \
  -e SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  -p 2222:22 \
  lockclaw-appliance:test

# Validate
docker exec lockclaw-appliance /opt/lockclaw/scripts/test-smoke.sh

# SSH in
ssh -p 2222 lockclaw@localhost
```

### Build VM artifacts (ISO/qcow2/raw)

```bash
cp image-builder/config/flavor.env.example image-builder/config/flavor.env
# Edit flavor.env, then:
make -C image-builder iso
make -C image-builder qcow2
make -C image-builder raw
```

### Deploy on bare metal / VM

1. Spin up a Linux VM (x86_64 or arm64) with a fresh Debian Bookworm install
2. Clone this repo
3. Run `scripts/build.sh` to apply hardening
4. Reboot and validate with `scripts/test-smoke.sh`

## Threat model

**What this protects against:**
- Unauthorized remote access (deny-default firewall, SSH hardened, fail2ban)
- Port scanning and brute-force attacks (fail2ban + nftables rate limiting)
- File tampering (AIDE baseline integrity monitoring)
- Rootkits and backdoors (rkhunter detection)
- Kernel-level attacks (sysctl hardening: rp_filter, syncookies, ptrace scope)
- Privilege escalation (auditd monitoring, sudo logging, modern password hashing)
- Unpatched vulnerabilities (unattended-upgrades for Debian security patches)

**What this does NOT protect against:**
- Physical access to the machine
- Zero-day kernel exploits (defense-in-depth, but no magic bullet)
- Insider threats with legitimate sudo access
- Supply chain attacks in upstream packages (mitigated by pinning)
- Application-level vulnerabilities in AI runtimes
- DDoS at the network level

**Assumptions:**
- SSH keys are managed securely by the operator
- The operator reviews Lynis reports and acts on findings
- AI runtimes are installed separately and bind to loopback
- Network access is further restricted by the operator's infrastructure (VPN, private network)

See [docs/threat-model.md](docs/threat-model.md) for the full model.

## Architecture

```
overlays/etc/security/    ← kernel, SSH, sudo, audit, fail2ban, logging policy
overlays/etc/network/     ← nftables firewall, resolver, NTP
packages/                 ← OS-level package manifests (security + networking)
scripts/                  ← build, smoke test, audit tooling
lockclaw-core/            ← shared audit scripts and port allowlists
image-builder/            ← VM artifact pipeline (ISO/qcow2/raw stubs + Makefile)
docs/                     ← threat model, security posture, networking posture
```

## Security scanning

```bash
# Full scan (AIDE + rkhunter + Lynis)
/opt/lockclaw/lockclaw-core/scanner/security-scan.sh

# Individual tools
/opt/lockclaw/lockclaw-core/scanner/security-scan.sh aide
/opt/lockclaw/lockclaw-core/scanner/security-scan.sh rkhunter
/opt/lockclaw/lockclaw-core/scanner/security-scan.sh lynis
```

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SSH_PUBLIC_KEY` | Yes | Public key for `lockclaw` user's `authorized_keys` |

## Docs

| Document | What it covers |
|----------|---------------|
| [Threat model](docs/threat-model.md) | Assets, threats, mitigations, assumptions |
| [Security posture](docs/security-posture.md) | All security overlays and policy |
| [Networking posture](docs/networking-posture.md) | Network overlays and exposure surface |

## Related projects

- **[lockclaw-baseline](https://github.com/iwes247/lockclaw-baseline)** — Container deployment baseline (Docker/Compose, no OS-level hardening)
- **[lockclaw-core](https://github.com/iwes247/lockclaw-core)** — Shared audit scripts and port allowlists

## License

MIT — see [LICENSE](LICENSE).
