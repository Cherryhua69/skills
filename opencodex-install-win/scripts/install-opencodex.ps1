[CmdletBinding()]
param(
    [string]$ProxyUrl = 'http://127.0.0.1:7890',
    [switch]$NoProxy
)

$ErrorActionPreference = 'Stop'

function Invoke-Native {
    param(
        [Parameter(Mandatory)] [string]$Command,
        [Parameter(ValueFromRemainingArguments)] [string[]]$Arguments
    )
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Command $($Arguments -join ' ')"
    }
}

if (-not $IsWindows) {
    throw 'This installer supports Windows only.'
}

$node = Get-Command node -ErrorAction SilentlyContinue
$npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $node -or -not $npm) {
    throw 'Node.js 18+ and npm are required. Install the current Node.js LTS, reopen PowerShell, and retry.'
}

$versionText = (& node --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Unable to read the Node.js version.' }
$nodeMajor = [int]($versionText.TrimStart('v').Split('.')[0])
if ($nodeMajor -lt 18) {
    throw "Node.js 18+ is required; found major version $nodeMajor."
}

$proxyKeys = @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY')
$priorProxyEnv = @{}
foreach ($key in $proxyKeys) {
    $priorProxyEnv[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}

try {
    if (-not $NoProxy) {
        $uri = [Uri]$ProxyUrl
        if ($uri.Scheme -notin @('http', 'https')) {
            throw 'ProxyUrl must be an HTTP or HTTPS proxy URL, for example http://127.0.0.1:7890.'
        }
        if (-not (Test-NetConnection -ComputerName $uri.Host -Port $uri.Port -InformationLevel Quiet)) {
            throw "The proxy endpoint is not listening: $($uri.Host):$($uri.Port)."
        }

        $env:HTTP_PROXY = $ProxyUrl
        $env:HTTPS_PROXY = $ProxyUrl
        $env:NO_PROXY = 'localhost,127.0.0.1,::1'
        Remove-Item Env:ALL_PROXY -ErrorAction SilentlyContinue
    }
    else {
        foreach ($key in $proxyKeys) {
            Remove-Item "Env:$key" -ErrorAction SilentlyContinue
        }
    }

    Invoke-Native npm install -g '@bitkyc08/opencodex'
    Invoke-Native ocx --version

    # Explicitly install/update the Windows background service and its startup task.
    Invoke-Native ocx service install
    # A restart proves that the running process was launched from the freshly written
    # definition instead of accepting an older healthy process as success.
    Invoke-Native ocx service restart

    $healthText = (& ocx health --json 2>$null | Out-String).Trim()
    $healthy = $false
    if ($healthText) {
        try { $healthy = [bool](($healthText | ConvertFrom-Json).ok) } catch { $healthy = $false }
    }

    if (-not $healthy) {
        throw 'OpenCodex service is not healthy after installation. Run: ocx service status'
    }

    if (-not $NoProxy) {
        $openCodexHome = if ($env:OPENCODEX_HOME) { $env:OPENCODEX_HOME } else { Join-Path $env:USERPROFILE '.opencodex' }
        $wrapper = Join-Path $openCodexHome 'opencodex-service.cmd'
        if (-not (Test-Path -LiteralPath $wrapper)) {
            throw "Task Scheduler service wrapper not found: $wrapper"
        }
        $wrapperText = Get-Content -Raw -LiteralPath $wrapper
        if ($wrapperText -notmatch [regex]::Escape("HTTP_PROXY=$ProxyUrl") -or
            $wrapperText -notmatch [regex]::Escape("HTTPS_PROXY=$ProxyUrl") -or
            $wrapperText -notmatch [regex]::Escape('NO_PROXY=localhost,127.0.0.1,::1')) {
            throw 'The service is healthy, but its wrapper does not contain the requested outbound proxy. Run: ocx service repair'
        }
    }

    Invoke-Native ocx service status
}
finally {
    foreach ($key in $proxyKeys) {
        $value = $priorProxyEnv[$key]
        if ($null -eq $value) {
            Remove-Item "Env:$key" -ErrorAction SilentlyContinue
        }
        else {
            [Environment]::SetEnvironmentVariable($key, $value, 'Process')
        }
    }
}

Write-Host ''
Write-Host 'OpenCodex is installed and the background service is healthy.' -ForegroundColor Green
if (-not $NoProxy) {
    Write-Host "Outbound proxy baked into the service: $ProxyUrl"
}
Write-Host 'OAuth remains a user action. Run this yourself:' -ForegroundColor Yellow
Write-Host '  ocx account login codex --device'
