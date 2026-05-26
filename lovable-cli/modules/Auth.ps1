# ── Auth.ps1 ──────────────────────────────────────────────────────────────────
# Handles the two-step auth flow:
#   1. Firebase JWT  (from browser DevTools — refreshed ~hourly)
#   2. Lovable JWT   (fetched from /auth-token using Firebase JWT + cookies)
#
# The Lovable JWT is cached in memory for the session and on disk with expiry.

$script:CachedLovableToken = $null
$script:CachedExpiry       = $null

function Get-LovableToken {
    param(
        [string]$ProjectId,
        [switch]$Force
    )

    # Return in-memory cache if still valid
    if (-not $Force -and $script:CachedLovableToken -and $script:CachedExpiry) {
        if ((Get-Date) -lt $script:CachedExpiry.AddMinutes(-5)) {
            return $script:CachedLovableToken
        }
    }

    $cred = Get-Credential
    if (-not $cred.firebase_token) {
        Write-Host "  No credentials found. Run:" -ForegroundColor Red
        Write-Host "    .\lovable-cli.ps1 set-token" -ForegroundColor Yellow
        exit 1
    }

    $Headers = Build-BaseHeaders -BearerToken $cred.firebase_token

    try {
        $Response = Invoke-RestMethod `
            -Uri     "$script:BaseUrl/projects/$ProjectId/auth-token" `
            -Method  GET `
            -Headers $Headers

        $script:CachedLovableToken = $Response.token
        $script:CachedExpiry       = [datetime]::Parse($Response.expires_at)

        $HoursLeft = [math]::Round(($script:CachedExpiry - (Get-Date)).TotalHours, 1)
        $Color     = if ($HoursLeft -lt 24) { "Yellow" } else { "Green" }

        Write-Host "  Auth token OK   : $($Response.project_name)" -ForegroundColor $Color
        Write-Host "  Expires         : $($Response.expires_at) ($HoursLeft hrs left)" -ForegroundColor DarkGray

        if ($HoursLeft -lt 0) {
            Write-Host "  Token EXPIRED — paste a fresh Firebase token" -ForegroundColor Red
            exit 1
        }

        return $script:CachedLovableToken
    }
    catch {
        Write-Host "  Auth failed: $($_.Exception.Message)" -ForegroundColor Red
        Invoke-ShowResponseBody $_
        exit 1
    }
}

function Build-BaseHeaders {
    param([string]$BearerToken)
    $cred = Get-Credential
    return @{
        "Authorization"    = "Bearer $BearerToken"
        "Content-Type"     = "application/json"
        "Accept"           = "*/*"
        "Accept-Language"  = "en-US,en;q=0.9"
        "x-client-git-sha" = $script:ClientGitSha
        "Cookie"           = $cred.session_cookie
        "Referer"          = "https://lovable.dev/"
        "sec-fetch-dest"   = "empty"
        "sec-fetch-mode"   = "cors"
        "sec-fetch-site"   = "same-site"
    }
}

function Invoke-ShowResponseBody {
    param($Err)
    if ($Err.Exception.Response) {
        try {
            $Stream = $Err.Exception.Response.GetResponseStream()
            $Body   = (New-Object System.IO.StreamReader($Stream)).ReadToEnd()
            Write-Host "  Response body: $Body" -ForegroundColor DarkYellow
        } catch {}
    }
}
