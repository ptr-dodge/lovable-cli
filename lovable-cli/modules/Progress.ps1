# ── Progress.ps1 ──────────────────────────────────────────────────────────────
# Renders an inline progress bar and live status line in the terminal.

$script:ProgressTotal   = 0
$script:ProgressCurrent = 0
$script:ProgressLabel   = ""
$script:ProgressErrors  = 0
$script:ProgressSkipped = 0

function Start-DownloadProgress {
    param([int]$Total, [string]$Label = "Downloading")
    $script:ProgressTotal   = $Total
    $script:ProgressCurrent = 0
    $script:ProgressErrors  = 0
    $script:ProgressSkipped = 0
    $script:ProgressLabel   = $Label
    Write-Host ""
}

function Update-DownloadProgress {
    param([string]$CurrentFile, [switch]$Skipped, [switch]$Error)

    $script:ProgressCurrent++
    if ($Skipped) { $script:ProgressSkipped++ }
    if ($Error)   { $script:ProgressErrors++ }

    $pct     = [int](($script:ProgressCurrent / $script:ProgressTotal) * 100)
    $filled  = [int](($pct / 100) * 40)
    $empty   = 40 - $filled
    $bar     = ("█" * $filled) + ("░" * $empty)
    $status  = if ($Skipped) { "skip" } elseif ($Error) { "ERR " } else { " OK " }
    $short   = if ($CurrentFile.Length -gt 45) { "..." + $CurrentFile.Substring($CurrentFile.Length - 42) } else { $CurrentFile }

    $line = "`r  [$bar] $pct% $($script:ProgressCurrent)/$($script:ProgressTotal)  $status  $short"
    Write-Host -NoNewline $line
}

function Complete-DownloadProgress {
    param([int]$Bytes)
    Write-Host ""
    $kb = [math]::Round($Bytes / 1KB, 1)
    Write-Host "  Done: $($script:ProgressCurrent) files  |  $($script:ProgressErrors) errors  |  $($script:ProgressSkipped) skipped  |  $kb KB written" -ForegroundColor Green
}

function Write-Section {
    param([string]$Title, [string]$Color = "Cyan")
    Write-Host "`n$('═' * 60)" -ForegroundColor DarkGray
    Write-Host "  $Title"      -ForegroundColor $Color
    Write-Host "$('─' * 60)"   -ForegroundColor DarkGray
}

function Write-FileTree {
    param([array]$Files)
    $groups = $Files | Group-Object { ($_.path -split '/')[0] } | Sort-Object Count -Descending
    foreach ($g in $groups) {
        $textFiles = ($g.Group | Where-Object { -not $_.binary }).Count
        $binFiles  = ($g.Group | Where-Object { $_.binary }).Count
        $kb        = [math]::Round(($g.Group | Measure-Object size -Sum).Sum / 1KB, 1)
        Write-Host ("  {0,-32} {1,3} files  {2,6} KB" -f $g.Name, $g.Count, $kb) -ForegroundColor DarkGray
    }
}
