# MoltClawLinux

Security- and networking-first skeleton for an OpenClaw-based Linux flavor.

## Goal

Create a Linux flavor named `MoltClawLinux` based on OpenClaw with security and networking as top priorities.

## OpenClaw baseline facts (authoritative)

- Upstream: `https://github.com/openclaw/openclaw.git`
- Base release/tag: `v2026.2.19` (default, override with `OPENCLAW_REF`)
- Package manager/format: npm/pnpm package `openclaw`; optional Nix (`nix-openclaw`)
- Image/build tooling used here: Docker (`docker build`, `docker compose`) and Nix (`home-manager switch`)
- Networking stack used by OpenClaw: Gateway WebSocket (`127.0.0.1:18789` default), optional SSH tunnel or Tailscale Serve/Funnel
- Target architectures: `x86_64` primary, `arm64` optional

## Flavor requirements (this repo)

- Primary priorities: security and networking
- Artifact type: container-first in this scaffold (Docker)
- Package set: see `packages/security-defaults.txt` and `packages/network-defaults.txt`
- Default services: network manager/resolver/time sync, logging/audit, optional OpenClaw gateway
- SSH: enabled with hardened config
- Firewall: enabled by policy; deny-by-default posture
- Updates: fixed baseline by tag/version; update with explicit verification (`openclaw doctor`)
- Users/admin: existing admin user + least-privilege sudo policy

## Repository layout

- `overlays/etc/security/`
	- `sysctl.conf`
	- `limits.conf`
	- `login.defs`
	- `sudoers.d/10-moltclaw-hardening`
	- `sshd_config.d/10-moltclaw-hardening.conf`
	- `audit/audit.rules`
	- `logging/journald.conf`
- `overlays/etc/network/`
	- `NetworkManager.conf`
	- `resolved.conf`
	- `timesyncd.conf`
- `packages/`
	- `security-defaults.txt`
	- `network-defaults.txt`
- `scripts/`
	- `build.sh`
	- `test-smoke.sh`
	- `audit.sh`
- `docs/`
	- `threat-model.md`
	- `security-posture.md`
	- `networking-posture.md`
- `ci/`
	- `build-and-smoke.sh`

Automation workflow:

- `.github/workflows/build-and-smoke.yml`

## Build

`scripts/build.sh docker` uses documented OpenClaw Docker flow.

`scripts/build.sh nix` uses documented `home-manager switch` flow (`HM_TARGET` required).

Artifact pipeline stubs for ISO/qcow2/raw are in `image-builder/`:

- `make -C image-builder validate`
- `make -C image-builder iso`
- `make -C image-builder qcow2`
- `make -C image-builder raw`

## Run in VM

This scaffold does not currently produce an ISO/qcow2 directly. Recommended VM path:

1. Provision a Linux VM (x86_64 or arm64) with Docker installed.
2. Clone this repo in the VM.
3. Run `scripts/build.sh docker`.
4. Validate with `scripts/test-smoke.sh`.

If you need ISO/qcow2/raw artifacts, add a dedicated image builder stage and keep these overlays as source-of-truth defaults.
Use the pre-wired stubs under `image-builder/` to stage that transition.

## Security posture

- Kernel hardening via `overlays/etc/security/sysctl.conf`
- Account/login policy via `overlays/etc/security/limits.conf` and `overlays/etc/security/login.defs`
- Sudo hardening via `overlays/etc/security/sudoers.d/10-moltclaw-hardening`
- SSH hardening via `overlays/etc/security/sshd_config.d/10-moltclaw-hardening.conf`
- Audit and logging via `overlays/etc/security/audit/audit.rules` and `overlays/etc/security/logging/journald.conf`

## Networking posture

- Network manager baseline: `overlays/etc/network/NetworkManager.conf`
- Resolver baseline: `overlays/etc/network/resolved.conf`
- Time sync baseline: `overlays/etc/network/timesyncd.conf`
- Gateway default surface is loopback-only unless explicitly exposed

## How to audit exposure

- Run structure + policy checks: `scripts/audit.sh`
- Run runtime smoke tests: `scripts/test-smoke.sh`
- CI validation: `.github/workflows/build-and-smoke.yml`
- See one-page design spec: `docs/design-spec.md`

## Validation

- `scripts/audit.sh` verifies required overlay files exist.
- `scripts/test-smoke.sh` validates boot, DHCP/default route, DNS, time sync, firewall policy, SSH policy, and update/verification path.