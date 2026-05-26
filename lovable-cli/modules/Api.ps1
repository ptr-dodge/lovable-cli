# ── Api.ps1 ───────────────────────────────────────────────────────────────────
# Typed wrappers for every Lovable API endpoint used by the CLI.

function Invoke-LovableApi {
    param(
        [string]$Path,
        [string]$Method  = "GET",
        [string]$Token,
        [object]$Body    = $null,
        [hashtable]$Query = @{}
    )

    $Uri = "$script:BaseUrl$Path"
    if ($Query.Count) {
        $qs = ($Query.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Web.HttpUtility]::UrlEncode($_.Value))" }) -join "&"
        $Uri += "?$qs"
    }

    $Headers = Build-BaseHeaders -BearerToken $Token
    $Params  = @{ Uri = $Uri; Method = $Method; Headers = $Headers; ErrorAction = "Stop" }
    if ($Body) { $Params.Body = ($Body | ConvertTo-Json -Depth 10) }

    try {
        return Invoke-RestMethod @Params
    }
    catch {
        $Code = $null
        try { $Code = $_.Exception.Response.StatusCode.value__ } catch {}
        if ($Code -eq 401) {
            Write-Host "  401 Unauthorized — Firebase token may have expired. Re-run set-token." -ForegroundColor Red
            exit 1
        }
        throw
    }
}

# ── Endpoint functions ────────────────────────────────────────────────────────

function Get-ProjectAuthToken {
    param([string]$ProjectId)
    return Get-LovableToken -ProjectId $ProjectId
}

function Get-ProjectConfig {
    param([string]$ProjectId, [string]$Token)
    return Invoke-LovableApi -Path "/projects/$ProjectId/config" -Token $Token
}

function Get-SecurityScan {
    param([string]$ProjectId, [string]$Token)
    return Invoke-LovableApi -Path "/projects/$ProjectId/security-scan" -Token $Token
}

function Get-GitFileList {
    param([string]$ProjectId, [string]$Ref, [string]$Token)
    return Invoke-LovableApi `
        -Path  "/projects/$ProjectId/git/files" `
        -Token $Token `
        -Query @{ ref = $Ref }
}

function Get-GitFileContent {
    param([string]$ProjectId, [string]$Ref, [string]$FilePath, [string]$Token)
    try {
        $Response = Invoke-LovableApi `
            -Path  "/projects/$ProjectId/git/file" `
            -Token $Token `
            -Query @{ ref = $Ref; path = $FilePath }
        return $Response
    }
    catch {
        $Code = $null
        try { $Code = $_.Exception.Response.StatusCode.value__ } catch {}
        return [PSCustomObject]@{ error = $true; code = $Code; path = $FilePath }
    }
}

function Get-CommitHistory {
    param([string]$ProjectId, [string]$Token, [int]$Limit = 20)
    return Invoke-LovableApi `
        -Path  "/projects/$ProjectId/git/commits" `
        -Token $Token `
        -Query @{ limit = "$Limit" }
}
