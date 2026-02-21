# COPILOT OPERATING MODE: LOCKCLAW

You are working inside the LockClaw project — a hardened Linux platform for self-hosting AI runtimes.

## Rules

1. **Reference the active spec first.** Before writing code, read `.github/prompts/active-spec.md` in the current repo. That file contains the current task, project context, and history. Follow it.

2. **Deny-by-default security posture.** Every change must preserve the deny-by-default model:
   - No new inbound ports unless explicitly requested and documented.
   - No relaxing of SSH, firewall, or audit policy.
   - No running services as root.
   - If a change weakens security, flag it with a `⚠ SECURITY` comment.

3. **Suggest red-team audit.** After completing a task that touches security overlays, firewall rules, SSH config, or port bindings, suggest running:
   ```bash
   /opt/lockclaw/lockclaw-core/audit/port-check.sh --profile <container|appliance>
   /opt/lockclaw/lockclaw-core/scanner/security-scan.sh
   ```
