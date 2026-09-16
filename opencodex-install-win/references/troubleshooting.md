# OpenCodex Windows troubleshooting

## `OAuth authentication failed`

Check whether the interactive shell has proxy variables while the Task Scheduler wrapper does not:

```powershell
Get-ChildItem Env: | Where-Object Name -Match '^(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY)$'
Select-String -Path "$env:USERPROFILE\.opencodex\opencodex-service.cmd" -Pattern 'HTTP_PROXY|HTTPS_PROXY|NO_PROXY'
```

If the wrapper lacks them, set process-only values and repair:

```powershell
$env:HTTP_PROXY='http://127.0.0.1:7890'
$env:HTTPS_PROXY='http://127.0.0.1:7890'
$env:NO_PROXY='localhost,127.0.0.1,::1'
Remove-Item Env:ALL_PROXY -ErrorAction SilentlyContinue
ocx service repair
ocx service restart
```

Then verify health. Only the user runs `ocx account login codex --device`.

## `ENAMETOOLONG` during service repair/restart

First inspect actual state; OpenCodex can report the spawn error even when it rewrote the wrapper and the service is healthy:

```powershell
ocx service status
ocx health --json
Select-String -Path "$env:USERPROFILE\.opencodex\opencodex-service.cmd" -Pattern 'HTTP_PROXY|HTTPS_PROXY|NO_PROXY'
```

If the wrapper is correct but the running process is stale, use OpenCodex's supported stop, wait for its respawn guard to finish, then start the existing task:

```powershell
ocx stop
Start-Sleep -Seconds 12
Start-ScheduledTask -TaskName 'opencodex-proxy'
ocx health --json
```

Do not kill an unidentified process or create a duplicate scheduled task.

## Port confusion

`7890` is usually Clash/Mihomo/Vortex's outbound proxy. OpenCodex normally listens on `10100`. Inspect ownership before changing either:

```powershell
Get-NetTCPConnection -State Listen -LocalPort 7890,10100 -ErrorAction SilentlyContinue |
    Select-Object LocalAddress,LocalPort,OwningProcess
```

## Diagnostics

```powershell
ocx doctor
ocx service status
ocx health --json
Get-Content "$env:USERPROFILE\.opencodex\service.log" -Tail 200
```

Treat logs and account files as sensitive. Do not copy credentials or unredacted tokens into reports.
