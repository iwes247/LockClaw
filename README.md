# LockClaw

A hardened Linux distribution layer built on [OpenClaw](https://github.com/openclaw/openclaw). LockClaw enforces a deny-by-default security model and ships production-ready networking defaults out of the box — no manual hardening required after deployment.

The container ships with the **OpenClaw AI gateway** (`ws://127.0.0.1:18789`) and **[claude-mem](https://github.com/thedotmack/claude-mem)** persistent memory pre-installed. Provide an API key and you have a working AI assistant with memory that persists across sessions.

## Why this exists

Most Linux setups ship permissive defaults and leave hardening as an exercise for the operator. LockClaw inverts that: security and networking policy are applied at build time through declarative overlays, validated by automated tests, and enforced by the firewall, SSH, and audit subsystems from first boot.

The base layer is OpenClaw `v2026.2.19` (pinned, overridable via `OPENCLAW_REF`). The gateway runs on Node.js 22 with claude-mem for persistent memory. Builds run through Docker or Nix. Image-builder stubs are in place for ISO/qcow2/raw artifact targets.

## Architecture

```
overlays/etc/security/    ← kernel, SSH, sudo, audit, fail2ban, logging policy
overlays/etc/network/     ← NetworkManager, resolver, NTP, nftables firewall
packages/                 ← OS-level package manifests (security + networking)
scripts/                  ← build, smoke test, and audit tooling
image-builder/            ← artifact pipeline (ISO/qcow2/raw stubs + Makefile)
docs/                     ← threat model, security posture, networking posture
ci/                       ← CI entrypoint; wired to GitHub Actions
```

## Security model

**Default posture: deny everything inbound. Allow only what's explicitly approved.**

| Layer | What it does | Config |
|-------|-------------|--------|
| Firewall | nftables drops all inbound; allows SSH (rate-limited), loopback, DHCP, established/related. Logged drops. | `overlays/etc/network/nftables.conf` |
| SSH | Key-only auth. No root login. Modern ciphers only (chacha20-poly1305, aes256-gcm). MaxAuthTries 3. | `overlays/etc/security/sshd_config.d/10-lockclaw-hardening.conf` |
| Brute-force | fail2ban bans IPs after 5 failed SSH attempts for 1 hour. | `overlays/etc/security/fail2ban/jail.local` |
| Port scanning | nftables logs dropped packets; fail2ban detects repeated drops and bans the scanner's IP for 24 hours. | `overlays/etc/security/fail2ban/filter.d/portscan.conf` |
| File integrity | AIDE monitors critical binaries and configs against a build-time baseline. Detects unauthorized modifications. | `overlays/etc/security/aide/aide.conf` |
| Rootkit detection | rkhunter scans for known rootkits, backdoors, and suspicious files. | `overlays/etc/security/rkhunter/rkhunter.conf.local` |
| Security audit | Lynis runs comprehensive hardening checks and produces a scored report. | Installed; run `lynis audit system --quick` |
| Auto updates | unattended-upgrades applies Debian security patches automatically. | `overlays/etc/security/apt/50unattended-upgrades` |
| Kernel | rp_filter, syncookies, no ICMP redirects, no source routing, ptrace restricted, BPF restricted, sysrq disabled. | `overlays/etc/security/sysctl.conf` |
| Accounts | yescrypt password hashing. 90-day password rotation. umask 027. | `overlays/etc/security/login.defs` |
| Sudo | PTY required. Full I/O logging to `/var/log/sudo.log`. 5-minute credential timeout. | `overlays/etc/security/sudoers.d/10-lockclaw-hardening` |
| Audit | auditd watches `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, `/etc/ssh/sshd_config`, nftables config, privilege escalation binaries. | `overlays/etc/security/audit/audit.rules` |
| Logging | journald with persistent storage + FSS sealing. rsyslog forwards auth/kern/daemon logs. logrotate on sudo.log. | `overlays/etc/security/logging/journald.conf` |

## Networking model

| Component | Configuration | Rationale |
|-----------|--------------|-----------|
| Network manager | NetworkManager with `dns=systemd-resolved` | Predictable DHCP + interface management |
| DNS | 1.1.1.1 / 9.9.9.9 primary, 8.8.8.8 / 1.0.0.1 fallback. DNSSEC enforced. DoT opportunistic. | Verified resolution by default |
| Discovery | mDNS disabled. LLMNR disabled. No Avahi. | Zero broadcast attack surface |
| Time sync | Cloudflare + Google NTP, pool.ntp.org fallback. | Reliable TLS cert validation and log timestamps |
| Exposure | OpenClaw gateway bound to `127.0.0.1:18789` only. SSH on `22/tcp` (hardened + rate-limited). Everything else dropped. | Minimal attack surface |

Remote access is via SSH tunnel or Tailscale — the gateway is never exposed directly.

## Quick start

### Pull (recommended)

```bash
docker pull ghcr.io/iwes247/lockclaw:latest
```

### Build from source (alternative)

```bash
git clone https://github.com/iwes247/LockClaw.git && cd LockClaw
scripts/build.sh            # builds lockclaw:latest
```

### Run

```bash
docker run -d --name lockclaw \
  --cap-add NET_ADMIN \
  --cap-add AUDIT_WRITE \
  -e SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  -e ANTHROPIC_API_KEY="sk-ant-..." \
  -p 2222:22 \
  lockclaw:latest
```

SSH in:
```bash
ssh -p 2222 lockclaw@localhost
```

The `lockclaw` user has sudo access. Root login is disabled. Password auth is disabled.

The OpenClaw gateway starts automatically on `ws://127.0.0.1:18789` (loopback only). Access it through SSH tunnel:

```bash
ssh -p 2222 -L 18789:127.0.0.1:18789 lockclaw@localhost
# Gateway is now available at ws://127.0.0.1:18789 on your machine
```

### Validate

```bash
# Run smoke tests inside the running container
docker exec lockclaw /opt/lockclaw/scripts/test-smoke.sh

# Check what's listening
docker exec lockclaw ss -tlnp

# Check firewall
docker exec lockclaw nft list ruleset
```

### Build (Nix, alternative)

```bash
export HM_TARGET=youruser
scripts/build.sh nix
```

### Build upstream OpenClaw only

```bash
scripts/build.sh upstream     # clones + builds OpenClaw without LockClaw hardening
```

### Build artifacts (ISO/qcow2/raw)

The image-builder pipeline is stubbed out and ready to wire to a real toolchain (mkosi, livebuild, Packer, etc.):

```bash
cp image-builder/config/flavor.env.example image-builder/config/flavor.env
# edit flavor.env, then:
make -C image-builder iso
make -C image-builder qcow2
make -C image-builder raw
```

### Run in a VM

1. Spin up a Linux VM (x86_64 or arm64) with Docker.
2. Clone this repo, run `scripts/build.sh`.
3. Run the container, then `docker exec lockclaw /opt/lockclaw/scripts/test-smoke.sh`.

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SSH_PUBLIC_KEY` | Yes | Public key injected into `lockclaw` user's `authorized_keys` |
| `ANTHROPIC_API_KEY` | For AI | API key for Anthropic models (claude-opus-4-6 default) |
| `OPENAI_API_KEY` | Optional | API key for OpenAI models |
| `OPENCLAW_REF` | No | Override pinned OpenClaw version (default: `v2026.2.19`) |
| `OPENCLAW_SHA` | No | Commit SHA for supply-chain verification |

## OpenClaw gateway

The gateway binds to loopback only (`127.0.0.1:18789`) and is never directly exposed. It supports multiple AI model providers — set the appropriate API key environment variable.

**claude-mem** provides persistent memory across sessions. Memory is stored at `/home/lockclaw/.openclaw/memory/` and survives container restarts if you mount a volume:

```bash
docker run -d --name lockclaw \
  --cap-add NET_ADMIN --cap-add AUDIT_WRITE \
  -e SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  -e ANTHROPIC_API_KEY="sk-ant-..." \
  -v lockclaw-memory:/home/lockclaw/.openclaw \
  -p 2222:22 \
  lockclaw:latest
```

After first boot, configure channels and onboard:

```bash
ssh -p 2222 lockclaw@localhost
openclaw onboard            # interactive setup wizard
openclaw gateway status     # check gateway health
```

## Supply chain

- OpenClaw is pinned to `v2026.2.19` by default. Override with `OPENCLAW_REF`.
- Optional commit-SHA verification: set `OPENCLAW_SHA` and the build will hard-fail on mismatch.
- OS packages are declared in `packages/security-defaults.txt` and `packages/network-defaults.txt`.

## CI

Every push and PR runs:
1. **ShellCheck** — lint all shell scripts.
2. **Audit** — verify overlay files exist and policy content is correct.
3. **Build** — build the Docker image, start a container, run smoke tests inside it, verify firewall and SSH hardening, check listening ports.

Workflow: `.github/workflows/build-and-smoke.yml` (read-only permissions).

## Docs

| Document | What it covers |
|----------|---------------|
| [Design spec](docs/design-spec.md) | One-page architecture, threat model, defaults rationale, exposure surface |
| [Threat model](docs/threat-model.md) | Assets, primary threats, mitigations |
| [Security posture](docs/security-posture.md) | All security overlays, explicit policy, operational guidance |
| [Networking posture](docs/networking-posture.md) | All network overlays, principles, exposure surface |

## Auditing exposure

```bash
# Full security scan (AIDE + rkhunter + Lynis)
docker exec lockclaw /opt/lockclaw/scripts/security-scan.sh

# Individual tools
docker exec lockclaw /opt/lockclaw/scripts/security-scan.sh aide      # file integrity
docker exec lockclaw /opt/lockclaw/scripts/security-scan.sh rkhunter  # rootkit scan
docker exec lockclaw /opt/lockclaw/scripts/security-scan.sh lynis     # security audit

# Check that all required policy files exist and contain correct values
scripts/audit.sh

# Runtime validation (or set LOCKCLAW_CI=1 for overlay-based checks)
scripts/test-smoke.sh

# What's actually listening?
ss -tlnp
```

## License

MIT — see [LICENSE](LICENSE).