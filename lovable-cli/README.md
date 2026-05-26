# lovable-cli

Download and inspect Lovable projects from PowerShell.

## Setup

```powershell
# 1. Save your credentials (one-time setup)
.\lovable-cli.ps1 set-token
# Paste your Firebase JWT and Cookie from browser DevTools when prompted.
# Credentials are saved to ~/.lovable-cli/config.json
```

**Where to find your credentials** — open DevTools on lovable.dev, Network tab,
click any `api.lovable.dev` request and copy:
- `Authorization: Bearer <...>` header value (Firebase JWT, valid ~1 hour)
- `Cookie: __cuid=...` header value

## Commands

| Command | Description |
|---|---|
| `set-token` | Save Firebase JWT + cookies to disk |
| `clone <id>` | Download full repo |
| `pull <id>` | Re-download, skip unchanged files |
| `ls <id>` | List files without downloading |
| `cat <id> <path>` | Print a single file to stdout |
| `info <id>` | Show config + security scan |
| `config` | Show stored credentials |

## Examples

```powershell
# List all files in the repo
.\lovable-cli.ps1 ls f8159769-4969-49fa-9a82-c02dc3df9d46

# Clone the full repo
.\lovable-cli.ps1 clone f8159769-4969-49fa-9a82-c02dc3df9d46

# Clone — skip binary files, custom output dir
.\lovable-cli.ps1 clone f8159769-4969-49fa-9a82-c02dc3df9d46 `
    --skip-binary --output ./pryma-iris

# Clone only source files
.\lovable-cli.ps1 clone f8159769-4969-49fa-9a82-c02dc3df9d46 `
    --include src/,supabase/

# Pull latest changes (incremental)
.\lovable-cli.ps1 pull f8159769-4969-49fa-9a82-c02dc3df9d46

# Print a specific file
.\lovable-cli.ps1 cat f8159769-4969-49fa-9a82-c02dc3df9d46 src/App.tsx

# Print the .env file
.\lovable-cli.ps1 cat f8159769-4969-49fa-9a82-c02dc3df9d46 .env

# Security scan + config info
.\lovable-cli.ps1 info f8159769-4969-49fa-9a82-c02dc3df9d46
```

## Output

Downloaded files are written to `./output/project-<id>/` by default, mirroring
the repo structure exactly. A `.lovable-manifest.json` is saved alongside with
the ref, timestamp, and any errors.

## Notes

- **Firebase tokens expire ~hourly.** Re-run `set-token` and paste a fresh token.
- **Binary files** (favicon, lockfiles) get a size stub by default unless you
  remove `--skip-binary`. The API returns their metadata but not content.
- **Throttle** defaults to 50ms between requests. Increase with `--throttle 200`
  if you hit rate limits.
