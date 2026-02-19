# Threat Model

## Assets
- Gateway control plane access
- Host credentials, API tokens, and workspace data
- Channel identities and allowed peer lists

## Primary threats
- Unauthorized remote access to gateway/dashboard
- Untrusted inbound messages triggering unsafe actions
- Privilege escalation through shell/tool execution
- Excessive network exposure and data exfiltration

## Security defaults
- Keep gateway loopback-bound unless explicit remote access is needed
- Use pairing/allowlist posture for inbound DM/channel access
- Prefer sandboxing for non-main sessions with no network by default
- Require SSH key auth; disable root/password login
- Persist logs and enable baseline auditing
