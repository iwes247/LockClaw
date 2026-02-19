# Networking Posture

## Defaults in this repo
- NetworkManager baseline in overlays/etc/network/NetworkManager.conf
- DNS resolver baseline in overlays/etc/network/resolved.conf (DNSSEC enforced, DoT opportunistic, no mDNS/LLMNR)
- Time sync baseline in overlays/etc/network/timesyncd.conf (Cloudflare + Google primary, pool.ntp.org fallback)
- Firewall baseline in overlays/etc/network/nftables.conf (deny-by-default, rate-limited SSH)

## Principles
- Minimize exposed services
- Prefer loopback bindings for local control planes
- Enforce deterministic DNS/time configuration
- Keep firewall policy explicit and testable
- No broadcast/discovery protocols (mDNS disabled, LLMNR disabled, no Avahi)

## Exposure surface
- OpenClaw gateway: 127.0.0.1:18789/tcp (default local-only)
- SSH admin plane: 22/tcp (hardened, rate-limited, fail2ban-protected)
- All other inbound: dropped and logged by nftables
- No additional inbound services should be exposed by default
