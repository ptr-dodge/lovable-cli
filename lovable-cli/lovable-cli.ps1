#!/usr/bin/env pwsh
# ═══════════════════════════════════════════════════════════════════════════════
#  lovable-cli.ps1  —  Download and inspect Lovable projects from the terminal
#
#  USAGE
#    .\lovable-cli.ps1 <command> [options]
#
#  COMMANDS
#    set-token                         Save Firebase token + cookies to disk
#    clone   <project-id> [ref]        Download full repo to ./output/<name>
#    pull    <project-id> [ref]        Re-download, skipping unchanged files
#    ls      <project-id> [ref]        List files without downloading
#    cat     <project-id> <path> [ref] Print a single file to stdout
#    info    <project-id>              Show project config + security scan
#    config                            Show stored credentials and known projects
#
#  EXAMPLES
#    .\lovable-cli.ps1 set-token
#    .\lovable-cli.ps1 clone f8159769-4969-49fa-9a82-c02dc3df9d46
#    .\lovable-cli.ps1 clone f8159769-4969-49fa-9a82-c02dc3df9d46 main --skip-binary
#    .\lovable-cli.ps1 ls    f8159769-4969-49fa-9a82-c02dc3df9d46
#    .\lovable-cli.ps1 cat   f8159769-4969-49fa-9a82-c02dc3df9d46 src/App.tsx
#    .\lovable-cli.ps1 info  f8159769-4969-49fa-9a82-c02dc3df9d46
# ═══════════════════════════════════════════════════════════════════════════════

param(
    [Parameter(Position=0)] [string] $Command    = "help",
    [Parameter(Position=1)] [string] $ProjectId  = "",
    [Parameter(Position=2)] [string] $Arg2       = "",     # ref OR file path depending on command
    [Parameter(Position=3)] [string] $Arg3       = "",     # ref when Arg2 is a file path

    [string]   $Output      = "",          # override output directory
    [string[]] $Include     = @(),         # path prefixes to include
    [string[]] $Exclude     = @(),         # path prefixes to exclude
    [switch]   $SkipBinary,
    [switch]   $DryRun,
    [int]      $Throttle    = 50           # ms between requests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Web

# ── Shared constants ──────────────────────────────────────────────────────────
$script:BaseUrl      = "https://api.lovable.dev"
$script:ClientGitSha = "2b6fd854db15b5a70136b96dbbcbbf5ac2316a39"
$script:DefaultRef   = "6c69829c14d2c766b8802f0f937aaff8fad4b4aa"  # pryma-iris tip

# ── Load modules ──────────────────────────────────────────────────────────────
$ModuleDir = Join-Path $PSScriptRoot "modules"
foreach ($mod in @("Config", "Auth", "Api", "Progress", "Downloader")) {
    . (Join-Path $ModuleDir "$mod.ps1")
}

# ── Banner ────────────────────────────────────────────────────────────────────
function Show-Banner {
    Write-Host ""
    Write-Host "  lovable-cli" -ForegroundColor Cyan -NoNewline
    Write-Host "  —  pryma-iris project tools" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-Help {
    Show-Banner
    @"
  COMMANDS
    set-token                          Save Firebase token + session cookies
    clone  <project-id> [ref]          Full repo download
    pull   <project-id> [ref]          Incremental update (skips unchanged)
    ls     <project-id> [ref]          List files (no download)
    cat    <project-id> <path> [ref]   Print file to stdout
    info   <project-id>                Config + security scan summary
    config                             Show saved credentials

  OPTIONS (clone / pull)
    --output    <dir>                  Destination directory (default: ./output/<name>)
    --include   src/,supabase/         Only fetch these path prefixes (comma-separated)
    --exclude   public/                Skip these path prefixes
    --skip-binary                      Replace binaries with size stubs
    --dry-run                          List files only, no writes
    --throttle  <ms>                   Delay between requests (default: 50)

  EXAMPLES
    .\lovable-cli.ps1 clone f8159769-4969-49fa-9a82-c02dc3df9d46
    .\lovable-cli.ps1 clone f8159769-4969-49fa-9a82-c02dc3df9d46 main --skip-binary --output ./myrepo
    .\lovable-cli.ps1 ls    f8159769-4969-49fa-9a82-c02dc3df9d46
    .\lovable-cli.ps1 cat   f8159769-4969-49fa-9a82-c02dc3df9d46 src/App.tsx
    .\lovable-cli.ps1 info  f8159769-4969-49fa-9a82-c02dc3df9d46
"@
}

# ── Resolve ref (use default if not supplied or looks like a path) ─────────────
function Resolve-Ref {
    param([string]$Candidate)
    if ($Candidate -and -not $Candidate.Contains('/') -and $Candidate.Length -ge 7) {
        return $Candidate
    }
    return $script:DefaultRef
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMANDS
# ═══════════════════════════════════════════════════════════════════════════════

switch ($Command.ToLower()) {

    # ── set-token ─────────────────────────────────────────────────────────────
    "set-token" {
        Show-Banner
        Write-Host "  Paste your Firebase JWT (from DevTools Authorization header):"
        Write-Host "  (ends with a long base64 string — press Enter twice when done)" -ForegroundColor DarkGray
        $token = Read-Host "  Token"

        Write-Host "`n  Paste your Cookie header value (from DevTools):"
        Write-Host "  (starts with __cuid= ...)" -ForegroundColor DarkGray
        $cookie = Read-Host "  Cookie"

        Set-FirebaseToken -Token $token -Cookie $cookie
        Write-Host "`n  Saved. Run a clone or ls to test:" -ForegroundColor Green
        Write-Host "    .\lovable-cli.ps1 ls $ProjectId" -ForegroundColor DarkGray
    }

    # ── config ────────────────────────────────────────────────────────────────
    "config" {
        Show-Banner
        Show-Config
    }

    # ── ls ────────────────────────────────────────────────────────────────────
    "ls" {
        if (-not $ProjectId) { Write-Host "  Usage: .\lovable-cli.ps1 ls <project-id> [ref]" -ForegroundColor Red; exit 1 }
        Show-Banner
        $ref   = Resolve-Ref $Arg2
        $token = Get-LovableToken -ProjectId $ProjectId
        Write-Section "File list  —  $ProjectId"
        $list  = Get-GitFileList -ProjectId $ProjectId -Ref $ref -Token $token
        $files = $list.files
        Write-FileTree -Files $files
        Write-Host ""
        $kb = [math]::Round(($files | Measure-Object size -Sum).Sum / 1KB, 1)
        Write-Host "  Total: $($files.Count) files  |  $kb KB  |  ref: $ref" -ForegroundColor Cyan
    }

    # ── clone ─────────────────────────────────────────────────────────────────
    "clone" {
        if (-not $ProjectId) { Write-Host "  Usage: .\lovable-cli.ps1 clone <project-id> [ref]" -ForegroundColor Red; exit 1 }
        Show-Banner
        $ref   = Resolve-Ref $Arg2
        $token = Get-LovableToken -ProjectId $ProjectId

        # Resolve output directory
        $cfg     = Get-ProjectAuthToken -ProjectId $ProjectId  # warms token cache
        $projCfg = Get-ProjectConfig -ProjectId $ProjectId -Token $token
        $name    = if ($projCfg) { "project-$ProjectId" } else { "project-$ProjectId" }
        $outDir  = if ($Output) { $Output } else { Join-Path "." "output" $name }

        Invoke-RepoDownload `
            -ProjectId   $ProjectId `
            -Ref         $ref `
            -Token       $token `
            -OutputDir   $outDir `
            -Include     $Include `
            -Exclude     $Exclude `
            -SkipBinary:$SkipBinary `
            -DryRun:$DryRun `
            -ThrottleMs  $Throttle
    }

    # ── pull (incremental) ────────────────────────────────────────────────────
    "pull" {
        if (-not $ProjectId) { Write-Host "  Usage: .\lovable-cli.ps1 pull <project-id> [ref]" -ForegroundColor Red; exit 1 }
        Show-Banner
        $ref    = Resolve-Ref $Arg2
        $token  = Get-LovableToken -ProjectId $ProjectId
        $outDir = if ($Output) { $Output } else { Join-Path "." "output" "project-$ProjectId" }

        Invoke-RepoDownload `
            -ProjectId   $ProjectId `
            -Ref         $ref `
            -Token       $token `
            -OutputDir   $outDir `
            -Include     $Include `
            -Exclude     $Exclude `
            -SkipBinary:$SkipBinary `
            -Resume `
            -DryRun:$DryRun `
            -ThrottleMs  $Throttle
    }

    # ── cat ───────────────────────────────────────────────────────────────────
    "cat" {
        if (-not $ProjectId -or -not $Arg2) {
            Write-Host "  Usage: .\lovable-cli.ps1 cat <project-id> <file-path> [ref]" -ForegroundColor Red
            exit 1
        }
        $filePath = $Arg2
        $ref      = Resolve-Ref $Arg3
        $token    = Get-LovableToken -ProjectId $ProjectId
        $content  = Get-GitFileContent -ProjectId $ProjectId -Ref $ref -FilePath $filePath -Token $token

        if ($content.error) {
            Write-Host "  Error fetching $filePath  (HTTP $($content.code))" -ForegroundColor Red
            exit 1
        }

        $text = if ($content -is [string]) { $content } `
                elseif ($content.content)  { $content.content } `
                else                       { $content | ConvertTo-Json -Depth 10 }
        Write-Host $text
    }

    # ── info ──────────────────────────────────────────────────────────────────
    "info" {
        if (-not $ProjectId) { Write-Host "  Usage: .\lovable-cli.ps1 info <project-id>" -ForegroundColor Red; exit 1 }
        Show-Banner
        $token = Get-LovableToken -ProjectId $ProjectId

        Write-Section "Project config"
        try {
            $cfg = Get-ProjectConfig -ProjectId $ProjectId -Token $token
            Write-Host "  Supabase project : $($cfg.prod.supabase_project_id)" -ForegroundColor Cyan
            Write-Host "  Supabase org     : $($cfg.prod.supabase_organization_id)" -ForegroundColor Cyan
            Write-Host "  Managed          : $($cfg.prod.is_managed_by_lovable)" -ForegroundColor DarkGray
            Write-Host "  Dev env          : $(if ($cfg.dev) { $cfg.dev } else { 'not configured' })" -ForegroundColor DarkGray
        } catch { Write-Host "  Could not fetch config: $_" -ForegroundColor Yellow }

        Write-Section "Security scan"
        try {
            $scan = Get-SecurityScan -ProjectId $ProjectId -Token $token
            foreach ($s in $scan.results.PSObject.Properties) {
                $findings = $s.Value.findings
                $active   = $findings | Where-Object { -not $_.ignore }
                $warns    = $active   | Where-Object { $_.level -eq "warn" }
                $color    = if ($warns.Count -gt 0) { "Yellow" } else { "Green" }
                Write-Host ("  [{0}]  {1} findings  |  {2} active warnings" -f $s.Name, $findings.Count, $warns.Count) -ForegroundColor $color
                foreach ($f in $warns) {
                    Write-Host "    ! $($f.name)" -ForegroundColor Yellow
                }
            }
        } catch { Write-Host "  Could not fetch security scan: $_" -ForegroundColor Yellow }
    }

    # ── help / default ────────────────────────────────────────────────────────
    default {
        Show-Help
    }
}
