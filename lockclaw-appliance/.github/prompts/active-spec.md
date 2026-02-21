# LockClaw Appliance — Active Spec

> **Phone → GitHub → VS Code bridge**
>
> Edit this file from your phone (via GPT or GitHub mobile), push to `main`,
> then run `vibe-sync` in VS Code. Copilot reads this and executes your intent.

---

## How to use this file

1. **On your phone (GPT):** Describe what you want built/changed. Have GPT write
   the spec into this file format. Commit and push to `main` from GitHub mobile.
2. **In VS Code:** Run `vibe-sync` (alias or script). It pulls latest and prints
   this file so Copilot has full context.
3. **Tell Copilot:** "Read the active spec and do what it says."

---

## Identity

- **GitHub user:** `iwes247`
- **Git config:**
  ```
  user.name  = iwes247
  user.email = iwes247@users.noreply.github.com
  ```
- **Never push as your work user.** Verify: `git config user.name` → `iwes247`

---

## Project summary

Full OS-level hardened Linux appliance for VMs and bare metal. Security controls
baked in at build time — not optional, not runtime-configurable.

### Architecture

```
overlays/etc/security/    ← kernel, SSH, sudo, audit, fail2ban, logging policy
overlays/etc/network/     ← nftables firewall, resolver, NTP
packages/                 ← OS-level package manifests
scripts/                  ← build, smoke test, audit tooling
lockclaw-core/            ← shared audit scripts + port allowlists (vendored)
image-builder/            ← VM artifact pipeline (ISO/qcow2/raw)
docs/                     ← threat model, security posture, networking posture
```

### Security layers

| Layer | Control |
|-------|---------|
| Firewall | nftables deny-default; SSH rate-limited |
| SSH | Key-only, no root, modern ciphers, MaxAuthTries 3 |
| Brute-force | fail2ban: 5 fails → 1hr ban |
| Port scanning | logged drops → fail2ban 24h ban |
| File integrity | AIDE baseline monitoring |
| Rootkit detection | rkhunter |
| Auto updates | unattended-upgrades (Debian security daily) |
| Kernel | rp_filter, syncookies, ptrace restricted, BPF restricted |
| Audit | auditd on identity/privilege/firewall files |
| Logging | journald persistent + FSS sealing + rsyslog |

### Related repos

- [lockclaw-baseline](https://github.com/iwes247/lockclaw-baseline) — Container deployment
- [lockclaw-core](https://github.com/iwes247/lockclaw-core) — Shared audit + port allowlists

---

## Current task

<!-- 
  PHONE USERS: Replace everything below this line with your task.
  Be specific — what to build, change, fix, or research.
  Copilot will read this and execute.
-->

_No active task. Edit this section from your phone and push to start._
