<div align="center">
  <img src="docs/assets/lockclaw-mark.png" width="96" height="96" alt="LockClaw logo" />
  <h1>LockClaw</h1>
  <p><b>Fail-closed security seatbelt for local LLM Docker deployments.</b></p>

  <p>
    <a href="https://github.com/iwes247/lockclaw-baseline">Baseline</a> •
    <a href="https://github.com/iwes247/lockclaw-appliance">Appliance</a> •
    <a href="https://github.com/iwes247/lockclaw-core">Core</a> •
    <a href="https://github.com/iwes247/LockClaw/issues">Issues</a>
  </p>

  <p>
    <img alt="license" src="https://img.shields.io/badge/license-MIT-informational" />
    <img alt="status" src="https://img.shields.io/badge/status-alpha-yellow" />
    <img alt="posture" src="https://img.shields.io/badge/posture-fail--closed-blue" />
  </p>

  <p>
    <sub>
      Default-deny mindset • Minimal exposed surface • Loopback-first patterns • Clear scope boundaries
    </sub>
  </p>
</div>

## Start Here (Pick One)

| If you want… | Use… | What you get |
|---|---|---|
| Safe-by-default container runtime posture | **[lockclaw-baseline](https://github.com/iwes247/lockclaw-baseline)** | Docker hardening defaults, loopback-first networking, minimal permissions |
| Host hardening (VPS/bare metal) | **[lockclaw-appliance](https://github.com/iwes247/lockclaw-appliance)** | Firewall, SSH hardening, auditd/fail2ban, host-level controls |
| Shared policies + contracts | **[lockclaw-core](https://github.com/iwes247/lockclaw-core)** | Policy files, audits, versioned interfaces (developer-oriented) |

**Most users should start with:** [lockclaw-baseline](https://github.com/iwes247/lockclaw-baseline)

## Quickstart (2 minutes)

1. Go to [lockclaw-baseline Quickstart](https://github.com/iwes247/lockclaw-baseline).
2. Validate that “success looks like” in baseline matches your environment.
3. Add [lockclaw-appliance](https://github.com/iwes247/lockclaw-appliance) only if you need host-level hardening.

## What LockClaw is

LockClaw is a modular security baseline that helps local LLM deployments default to fail-closed posture with clear scope boundaries.

- **Baseline:** container/runtime guardrails
- **Appliance:** host hardening controls
- **Core:** shared policies, audits, and versioned interfaces

## What LockClaw is NOT

- Not a replacement for host security hygiene
- Not “secure by magic”
- Not a vulnerability scanner product
- Not a one-click internet-exposed deployment guide

## How the repos fit together

```text
LockClaw (landing)
  ├─ lockclaw-baseline  (container posture)
  │    └─ vendors lockclaw-core (policies + audits)
  └─ lockclaw-appliance (host posture)
       └─ consumes lockclaw-core conventions (where applicable)
```

## Why this exists

Many local-LLM guides normalize risky defaults, including published ports, broad container permissions, and unclear boundaries between container and host responsibilities.

LockClaw makes the safer path easier to follow while keeping assumptions and scope explicit.

## Contributing

Contributing workflow (spec-first) lives in [lockclaw-core/CONTRIBUTING.md](https://github.com/iwes247/lockclaw-core/blob/main/CONTRIBUTING.md).

## Legacy (pre-split)

Historical notes from before the repo split live under [docs/legacy/](docs/legacy/).
