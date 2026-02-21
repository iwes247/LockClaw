# LockClaw Core

Shared policy definitions, audit scripts, and port allowlists consumed by [lockclaw-baseline](https://github.com/iwes247/lockclaw-baseline) and [lockclaw-appliance](https://github.com/iwes247/lockclaw-appliance).

> **⚠️ Core is not a standalone install target.**
> Most users should not clone this repo directly.
> It is vendored (`lockclaw-core/`) into each consuming repo.
> Start with [lockclaw-baseline](https://github.com/iwes247/lockclaw-baseline) or [lockclaw-appliance](https://github.com/iwes247/lockclaw-appliance) instead.

## Start Here (Pick One)

| I want to… | Use |
|------------|-----|
| Run AI runtimes in Docker with sane security defaults | [lockclaw-baseline](https://github.com/iwes247/lockclaw-baseline) |
| Harden a VM or bare-metal host for AI workloads | [lockclaw-appliance](https://github.com/iwes247/lockclaw-appliance) |
| Understand the shared audit/policy layer | **lockclaw-core** *(you are here — vendored, not standalone)* |

## How the repos fit together

```
┌───────────────────┐     ┌────────────────────┐
│ lockclaw-baseline │     │ lockclaw-appliance  │
│  (Docker / OCI)   │     │ (VM / bare metal)   │
└────────┬──────────┘     └────────┬───────────┘
         │                         │
         └───────────┬─────────────┘
                     │ vendored at lockclaw-core/
              ┌──────▼──────┐
              │ lockclaw-core│
              │  (policies,  │
              │  audit, scan)│
              └──────────────┘
```

## Success looks like

- Every listening port appears in the allowlist — or the build fails.
- SSH (when enabled) accepts only key-based auth with modern ciphers.
- No runtime process runs as root.
- Smoke tests exit 0 on a clean build with zero manual steps.
- A newcomer can identify which repo to use in under 15 seconds.

## Contents

| Path | Purpose |
|------|---------|
| `audit/audit.sh` | Validate that required policy files exist and contain correct values |
| `audit/port-check.sh` | Verify no unexpected ports are listening (hard-fail, allowlist-driven) |
| `policies/ports/` | Per-profile port allowlists (JSON) |
| `policies/ssh-requirements.txt` | Required SSH posture values |
| `policies/sysctl-requirements.txt` | Required sysctl values (appliance only) |
| `scanner/security-scan.sh` | Wrapper for AIDE + rkhunter + Lynis (appliance runtime) |
| `docs/threat-model-template.md` | Template for per-repo threat models |

## Usage

### From lockclaw-baseline

```bash
# Vendored at ./lockclaw-core/
./lockclaw-core/audit/port-check.sh --profile container
```

### From lockclaw-appliance

```bash
# Vendored at ./lockclaw-core/
./lockclaw-core/audit/audit.sh --overlay-dir ./overlays
./lockclaw-core/audit/port-check.sh --profile appliance
./lockclaw-core/scanner/security-scan.sh
```

## Stability Contract

The following are considered **stable API** — breaking changes will bump the major version:

| Stable | Path / Format |
|--------|---------------|
| Port allowlists | `policies/ports/*.json` — JSON schema: `{ "allowed": [{ "port": N, "proto": "tcp" }] }` |
| SSH requirements | `policies/ssh-requirements.txt` — `key=value` per line |
| Sysctl requirements | `policies/sysctl-requirements.txt` — `key=value` per line |
| Audit script interface | `audit/audit.sh --overlay-dir <path>` exits 0 on pass, 1 on fail |
| Port-check interface | `audit/port-check.sh --profile <name>` exits 0 on pass, 1 on fail |
| Scanner interface | `scanner/security-scan.sh [aide\|rkhunter\|lynis]` exits 0 on pass, 1 on fail |

The following are **explicitly unstable** (may change without notice):

- Internal helper functions inside scripts
- Output formatting (human-readable text, not parsed by consumers)
- `docs/` templates and wording
- Exact package lists or tool versions used by `security-scan.sh`

## Versioning & Compatibility

Tag releases as `core-vX.Y.Z` following [SemVer](https://semver.org):

| Change type | Version bump | Example |
|-------------|--------------|---------|
| New policy file or script | Minor (`X.Y+1.0`) | Add `policies/ports/dmz.json` |
| Fix in existing script (no interface change) | Patch (`X.Y.Z+1`) | Fix arithmetic bug in `audit.sh` |
| Change to stable path, schema, or exit code | **Major** (`X+1.0.0`) | Rename `policies/ports/` → `policies/allowlists/` |

**How consuming repos should pin:**

1. Vendor `lockclaw-core/` at a known tag (e.g., `core-v1.2.0`).
2. CI smoke tests will catch breakage on update.
3. To upgrade: update the vendored copy, run smoke tests, commit.
4. Never track `main` directly in production — always pin to a tag.

## Contributing — vibe-sync workflow

This project uses a phone-to-VSCode bridge for development:

1. **From your phone** — Edit `.github/prompts/active-spec.md` via GPT, commit and push.
2. **At your workstation** — Run `lets-go` (PowerShell) or `./scripts/vibe-sync.sh` to pull the spec.
3. **Copilot executes** — VS Code Copilot reads the active spec and implements the task.
4. **Sync back** — Run `sync-vibe` to archive the completed task and push state back for your phone.

## License

MIT — see [LICENSE](LICENSE).
