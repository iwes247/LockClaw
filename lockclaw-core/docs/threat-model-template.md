# Threat Model Template

Use this template when documenting the threat model for a LockClaw-consuming project.

## Assets

_What are you protecting?_

| Asset | Description | Location |
|-------|-------------|----------|
| AI runtime API | e.g., Ollama, OpenClaw | `127.0.0.1:PORT` |
| API keys | Provider credentials | Environment variables |
| Model data | Downloaded LLM weights | `/home/lockclaw/.ollama/models` |
| SSH access | Administrative shell | Port 22 (if enabled) |
| Conversation data | User interactions | Runtime memory / disk |

## Threat actors

| Actor | Capability | Motivation |
|-------|-----------|------------|
| External attacker | Network scanning, brute-force | Unauthorized access, crypto mining |
| Adjacent network user | LAN access, ARP spoofing | Data exfiltration |
| Insider | Legitimate SSH/sudo access | Privilege escalation |

## Threats and mitigations

| # | Threat | Mitigation | Status |
|---|--------|-----------|--------|
| T1 | AI API exposed to network | Loopback-only binding (`127.0.0.1`) | ☐ Verify |
| T2 | SSH brute-force | Key-only auth, fail2ban (appliance), rate limiting | ☐ Verify |
| T3 | Unauthorized port exposure | Port allowlist audit (hard-fail) | ☐ Verify |
| T4 | File tampering | AIDE baseline monitoring (appliance) | ☐ Verify |
| T5 | Rootkit installation | rkhunter scanning (appliance) | ☐ Verify |
| T6 | Unpatched CVEs | unattended-upgrades (appliance) | ☐ Verify |
| T7 | Container escape | Minimal capabilities, non-root user | ☐ Verify |

## Assumptions

- [ ] Host has a firewall or is on a private network
- [ ] SSH keys are managed securely
- [ ] Docker daemon is properly configured (baseline)
- [ ] Operator reviews security scan output periodically (appliance)

## Validation

```bash
# Run smoke tests
/opt/lockclaw/scripts/test-smoke.sh

# Run port audit
/opt/lockclaw/lockclaw-core/audit/port-check.sh --profile <container|appliance>

# Run full security scan (appliance only)
/opt/lockclaw/lockclaw-core/scanner/security-scan.sh
```

## Sign-off

| Date | Reviewer | Notes |
|------|----------|-------|
| | | |
