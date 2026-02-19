# Networking Posture

## Defaults in this repo
- NetworkManager baseline in overlays/etc/network/NetworkManager.conf
- DNS resolver baseline in overlays/etc/network/resolved.conf
- Time sync baseline in overlays/etc/network/timesyncd.conf

## Principles
- Minimize exposed services
- Prefer loopback bindings for local control planes
- Enforce deterministic DNS/time configuration
- Keep firewall policy explicit and testable

## Exposure surface
- OpenClaw gateway: 127.0.0.1:18789/tcp (default local-only)
- SSH admin plane: 22/tcp (hardened)
- No additional inbound services should be exposed by default
