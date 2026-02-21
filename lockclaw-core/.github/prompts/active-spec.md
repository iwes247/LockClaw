# LockClaw Core — Active Spec

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

Shared policy definitions, audit scripts, and port allowlists consumed by
lockclaw-baseline and lockclaw-appliance. Not standalone — vendored or
submoduled into each consumer.

### Contents

| Path | Purpose |
|------|---------|
| `audit/audit.sh` | Validate policy files exist with correct values |
| `audit/port-check.sh` | Verify no unexpected ports listening (hard-fail) |
| `policies/ports/` | Per-profile port allowlists (JSON) |
| `policies/ssh-requirements.txt` | Required SSH posture values |
| `policies/sysctl-requirements.txt` | Required sysctl values (appliance only) |
| `scanner/security-scan.sh` | AIDE + rkhunter + Lynis wrapper (appliance) |

### Related repos

- [lockclaw-appliance](https://github.com/iwes247/lockclaw-appliance) — OS-level hardening
- [lockclaw-baseline](https://github.com/iwes247/lockclaw-baseline) — Container deployment

---

## Current task

<!-- 
  PHONE USERS: Replace everything below this line with your task.
  Be specific — what to build, change, fix, or research.
  Copilot will read this and execute.
-->

_No active task. Edit this section from your phone and push to start._
