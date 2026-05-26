# ── Downloader.ps1 ────────────────────────────────────────────────────────────
# Core repo download engine.
# Supports: full clone, diff/resume, skip-binary, filter by path prefix.

function Invoke-RepoDownload {
    param(
        [string]   $ProjectId,
        [string]   $Ref,
        [string]   $Token,
        [string]   $OutputDir,
        [string[]] $Include       = @(),       # path prefixes to include (empty = all)
        [string[]] $Exclude       = @(),       # path prefixes to exclude
        [switch]   $SkipBinary,               # skip binary files
        [switch]   $Resume,                   # skip files that already exist on disk
        [switch]   $DryRun,                   # list files but don't write
        [int]      $ThrottleMs    = 50         # ms between requests (be polite)
    )

    Write-Section "Fetching file list"
    $fileList = Get-GitFileList -ProjectId $ProjectId -Ref $Ref -Token $Token

    if (-not $fileList -or -not $fileList.files) {
        Write-Host "  No files returned." -ForegroundColor Red
        return
    }

    $allFiles = $fileList.files

    # ── Apply filters ────────────────────────────────────────────────────────
    if ($SkipBinary) {
        $allFiles = $allFiles | Where-Object { -not $_.binary }
    }
    if ($Include.Count -gt 0) {
        $allFiles = $allFiles | Where-Object {
            $p = $_.path
            $Include | Where-Object { $p.StartsWith($_) } | Select-Object -First 1
        }
    }
    if ($Exclude.Count -gt 0) {
        $allFiles = $allFiles | Where-Object {
            $p = $_.path
            -not ($Exclude | Where-Object { $p.StartsWith($_) } | Select-Object -First 1)
        }
    }

    $totalFiles = $allFiles.Count
    $totalSize  = ($allFiles | Measure-Object size -Sum).Sum

    Write-Host "  Ref      : $Ref"                                            -ForegroundColor DarkGray
    Write-Host "  Files    : $totalFiles  ($([math]::Round($totalSize/1KB,1)) KB)"  -ForegroundColor DarkGray
    Write-Host "  Output   : $OutputDir"                                       -ForegroundColor DarkGray
    if ($DryRun) { Write-Host "  [DRY RUN — no files will be written]" -ForegroundColor Yellow }

    if ($DryRun) {
        Write-Section "File list (dry run)"
        $allFiles | ForEach-Object {
            $flag = if ($_.binary) { " [binary]" } else { "" }
            Write-Host "  $($_.path)$flag" -ForegroundColor DarkGray
        }
        return
    }

    # ── Create output directory ───────────────────────────────────────────────
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

    # ── Download loop ─────────────────────────────────────────────────────────
    Write-Section "Downloading $totalFiles files"
    Start-DownloadProgress -Total $totalFiles

    $bytesWritten  = 0
    $errors        = @()

    foreach ($file in $allFiles) {
        $destPath = Join-Path $OutputDir ($file.path -replace '/', [System.IO.Path]::DirectorySeparatorChar)

        # Resume: skip if exists and size matches
        if ($Resume -and (Test-Path $destPath)) {
            $existing = (Get-Item $destPath).Length
            if ($existing -eq $file.size) {
                Update-DownloadProgress -CurrentFile $file.path -Skipped
                continue
            }
        }

        # Binary files: store a placeholder stub
        if ($file.binary) {
            $dir = Split-Path $destPath
            if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
            "[binary file — $($file.size) bytes — fetch manually]" | Out-File $destPath
            Update-DownloadProgress -CurrentFile $file.path
            $bytesWritten += $file.size
            if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds ($ThrottleMs / 4) }
            continue
        }

        # Text files: fetch content
        try {
            $content = Get-GitFileContent `
                -ProjectId $ProjectId `
                -Ref       $Ref `
                -FilePath  $file.path `
                -Token     $Token

            if ($content.error) {
                Update-DownloadProgress -CurrentFile $file.path -Error
                $errors += [PSCustomObject]@{ path = $file.path; code = $content.code }
            }
            else {
                # Content may be a string directly or wrapped in a .content property
                $text = if ($content -is [string]) { $content } `
                        elseif ($content.content)  { $content.content } `
                        else                       { $content | ConvertTo-Json -Depth 5 }

                $dir = Split-Path $destPath
                if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
                [System.IO.File]::WriteAllText($destPath, $text, [System.Text.Encoding]::UTF8)
                $bytesWritten += $file.size
                Update-DownloadProgress -CurrentFile $file.path
            }
        }
        catch {
            Update-DownloadProgress -CurrentFile $file.path -Error
            $errors += [PSCustomObject]@{ path = $file.path; error = $_.Exception.Message }
        }

        if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
    }

    Complete-DownloadProgress -Bytes $bytesWritten

    # ── Save manifest ─────────────────────────────────────────────────────────
    $manifest = [PSCustomObject]@{
        project_id   = $ProjectId
        ref          = $Ref
        downloaded_at = (Get-Date -Format "o")
        total_files  = $totalFiles
        bytes_written = $bytesWritten
        errors       = $errors
        files        = $allFiles | Select-Object path, size, binary
    }
    $manifest | ConvertTo-Json -Depth 5 | Out-File (Join-Path $OutputDir ".lovable-manifest.json")

    if ($errors.Count -gt 0) {
        Write-Host "`n  Failed files ($($errors.Count)):" -ForegroundColor Yellow
        $errors | ForEach-Object { Write-Host "    $($_.path)" -ForegroundColor DarkYellow }
    }

    return $manifest
}
