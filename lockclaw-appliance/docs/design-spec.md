# LockClaw Security + Networking Design Spec

LockClaw is a security- and networking-first Linux flavor layout for running OpenClaw.

## Authoritative OpenClaw facts used

- Upstream: `https://github.com/openclaw/openclaw.git`
- Base release/tag for this repo defaults: `v2026.2.19` (override via `OPENCLAW_REF`)
- Package manager/format: npm/pnpm package `openclaw`; Nix flake via `nix-openclaw`
- Build/image tooling documented by OpenClaw: Docker (`docker build`, `docker compose`), Nix (`home-manager switch`)
- Networking stack documented by OpenClaw: Gateway WebSocket on `127.0.0.1:18789`; remote access via SSH tunnel or Tailscale Serve/Funnel
- Target architectures in scope: `x86_64` (primary), `arm64` (optional)

## Threat model (top threats)

1. Unauthorized control-plane access to gateway/dashboard
2. Unsafe execution from untrusted inbound messages/channels
3. Host privilege escalation via shell/tool paths
4. Data exfiltration from broad network exposure or weak defaults
5. Drift/rollback risk from uncontrolled updates

## Secure defaults and rationale

- **Loopback-first gateway binding**: keeps control plane local by default; reduces remote attack surface.
- **Hardened SSH profile**: disable root and password auth; restrict to modern ciphers (chacha20-poly1305, aes256-gcm), KexAlgorithms (curve25519), and MACs (hmac-sha2-etm); key-based admin access only.
- **Deny-by-default firewall**: nftables ruleset drops all inbound except SSH (rate-limited), DHCP, loopback, and established/related. No ufw/firewalld abstraction layer.
- **Brute-force protection**: fail2ban sshd jail bans IPs after 5 failed attempts for 1 hour.
- **Kernel/account/sudo hardening overlays**: rp_filter, syncookies, ICMP restrictions, ptrace scope, BPF disabled for unprivileged, yescrypt password hashing.
- **Audit + persistent logging**: journald with sealing + rsyslog forwarding + auditd watching identity/firewall/privilege-escalation files + logrotate for sudo.log.
- **Fixed update posture**: default to pinned OpenClaw tag/version with optional commit SHA verification and explicit update steps (`openclaw doctor` after update).

## Networking defaults and rationale

- **Network manager**: NetworkManager + systemd-resolved + systemd-timesyncd for predictable host networking.
- **DNS**: explicit resolver configuration with DNSSEC enforced (`DNSSEC=yes`) and DoT in opportunistic mode. mDNS and LLMNR disabled.
- **DHCP**: default IPv4 addressing via DHCP on active uplink.
- **Time sync**: explicit NTP servers (Cloudflare, Google) with pool.ntp.org fallback to keep TLS/verification and logs reliable.
- **Remote access model**: prefer SSH tunnels or Tailscale over direct public exposure.
- **Firewall**: nftables deny-by-default ruleset with rate-limited SSH, DHCP client, and established/related. Logged drops.

## Exposure surface

- OpenClaw Gateway: `127.0.0.1:18789/tcp` (local only by default)
- SSH (admin plane): `22/tcp` (enabled with hardened config + rate-limited in nftables + fail2ban jail)
- Firewall: nftables deny-by-default; all other inbound dropped and logged
- No additional inbound ports opened by default policy

## Flavor profile

- Artifact target in this repo: container-first build path (Docker), with Nix profile path for managed hosts
- Update model: fixed/pinned baseline by tag/version; controlled promotion forward
- User/admin policy: existing admin user with least privilege + sudo policy, no password SSH auth