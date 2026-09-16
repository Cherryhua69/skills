---
name: opencodex-install-win
description: Use when installing, migrating, repairing, or configuring OpenCodex on Windows with npm, Task Scheduler background startup, a local HTTP proxy such as 127.0.0.1:7890, or Codex device OAuth errors.
---

# Install OpenCodex on Windows

Install the official npm package, bake the requested outbound proxy into the Windows background service, and verify observable health. Keep OpenCodex's listener (normally `10100`) distinct from the outbound proxy port (commonly `7890`).

## Workflow

1. Confirm Windows, Node.js 18+, npm, and the requested proxy endpoint. If Node.js is absent, ask the user to install the current LTS or run `winget install --id OpenJS.NodeJS.LTS`, then reopen PowerShell. If port `7890` is already owned by Clash/Mihomo/Vortex, treat it as the outbound proxy—not OpenCodex's listener.
2. Read the repository's current `AGENTS_INSTALL.md` when a source checkout is available. Never star the GitHub repository or answer a star prompt for the user.
3. Run `scripts/install-opencodex.ps1`. Override `-ProxyUrl` when needed; use `-NoProxy` only when the user explicitly wants direct egress.
4. Run `ocx service install` by default after setting the process proxy environment so the Task Scheduler wrapper receives `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY`; then restart the service to prove the running process uses the fresh definition.
5. Verify `ocx --version`, `ocx service status`, and `ocx health --json`. Do not call the installation complete from command output alone if health is false.
6. Finish by returning this command to the user without running it:

```powershell
ocx account login codex --device
```

OAuth authorization, device-code entry, quota refresh, and account consent remain user actions. Do not wait for, capture, transfer, or store credentials, device codes, email addresses, `auth.json`, API tokens, or admin tokens.

## Troubleshooting

Read [references/troubleshooting.md](references/troubleshooting.md) when OAuth reports `OAuth authentication failed`, the service does not inherit the proxy, `ENAMETOOLONG` appears, or the health check fails.

## Quick reference

| Goal | Command |
|---|---|
| Install/upgrade CLI | `npm install -g @bitkyc08/opencodex` |
| Install background startup | `ocx service install` |
| Repair an existing service | `ocx service repair` |
| Inspect service | `ocx service status` |
| Check health | `ocx health --json` |
| User-run OAuth | `ocx account login codex --device` |
| Remove service | `ocx service uninstall` |

Do not persist machine-wide or user-wide proxy variables unless the user explicitly requests that broader change. The installer temporarily sets them in the calling process so OpenCodex can bake them into its own service definition, then restores the prior values.
