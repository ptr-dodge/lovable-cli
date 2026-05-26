# ── Config.ps1 ────────────────────────────────────────────────────────────────
# Manages persistent credentials and per-project config via a local JSON store.
# Config file lives at: ~/.lovable-cli/config.json

$script:ConfigDir  = Join-Path $HOME ".lovable-cli"
$script:ConfigFile = Join-Path $script:ConfigDir "config.json"

function Initialize-Config {
    if (-not (Test-Path $script:ConfigDir)) {
        New-Item -ItemType Directory -Path $script:ConfigDir | Out-Null
    }
    if (-not (Test-Path $script:ConfigFile)) {
        @{ credentials = @{}; projects = @{} } | ConvertTo-Json | Out-File $script:ConfigFile
    }
}

function Get-Config {
    Initialize-Config
    return Get-Content $script:ConfigFile -Raw | ConvertFrom-Json
}

function Save-Config {
    param([object]$Config)
    $Config | ConvertTo-Json -Depth 10 | Out-File $script:ConfigFile
}

function Get-Credential {
    $cfg = Get-Config
    return $cfg.credentials
}

function Set-FirebaseToken {
    param([string]$Token, [string]$Cookie)
    $cfg = Get-Config
    $cfg.credentials = @{
        firebase_token = $Token
        session_cookie = $Cookie
        saved_at       = (Get-Date -Format "o")
    }
    Save-Config $cfg
    Write-Host "  Credentials saved to $script:ConfigFile" -ForegroundColor DarkGray
}

function Get-ProjectConfig {
    param([string]$ProjectId)
    $cfg = Get-Config
    if ($cfg.projects.PSObject.Properties[$ProjectId]) {
        return $cfg.projects.$ProjectId
    }
    return $null
}

function Set-ProjectConfig {
    param([string]$ProjectId, [object]$Data)
    $cfg = Get-Config
    $cfg.projects | Add-Member -MemberType NoteProperty -Name $ProjectId -Value $Data -Force
    Save-Config $cfg
}

function Show-Config {
    $cfg = Get-Config
    $cred = $cfg.credentials
    Write-Host "`n  Stored credentials:" -ForegroundColor Cyan
    if ($cred.firebase_token) {
        $preview = $cred.firebase_token.Substring(0, [Math]::Min(40, $cred.firebase_token.Length))
        Write-Host "    Firebase token : $preview..." -ForegroundColor DarkGray
        Write-Host "    Saved at       : $($cred.saved_at)" -ForegroundColor DarkGray
    } else {
        Write-Host "    (none — run: .\lovable-cli.ps1 set-token)" -ForegroundColor DarkYellow
    }

    Write-Host "`n  Known projects:" -ForegroundColor Cyan
    $count = ($cfg.projects.PSObject.Properties | Measure-Object).Count
    if ($count -eq 0) {
        Write-Host "    (none yet)" -ForegroundColor DarkGray
    } else {
        foreach ($p in $cfg.projects.PSObject.Properties) {
            Write-Host "    $($p.Name) → $($p.Value.name)" -ForegroundColor DarkGray
        }
    }
}
