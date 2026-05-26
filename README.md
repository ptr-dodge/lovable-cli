# lovable-cli

> Download and inspect Lovable.dev projects from PowerShell

A lightweight CLI for syncing Lovable projects locally—perfect for version control, automation, and bulk operations.

---

## 🚀 Quick Start

### 1. Authenticate (One-Time)

```powershell
.\lovable-cli.ps1 set-token
```

When prompted, paste your **Firebase JWT** and **Cookie** from the browser.

**How to get credentials:**
1. Open lovable.dev in your browser
2. Press `F12` → **Network** tab
3. Click any `api.lovable.dev` request
4. Copy the values:
   - `Authorization: Bearer <...>` (Firebase JWT)
   - `Cookie: __cuid=...`

Your credentials are encrypted and saved to `~/.lovable-cli/config.json`.

### 2. Clone a Project

```powershell
.\lovable-cli.ps1 clone f8159769-4969-49fa-9a82-c02dc3df9d46
```

Files appear in `./output/project-<id>/`.

---

## 📋 Commands

| Command | Description |
|---------|-------------|
| `set-token` | Save/update Firebase JWT + cookies |
| `clone <id>` | Download entire project |
| `pull <id>` | Sync latest changes (incremental) |
| `ls <id>` | List files without downloading |
| `cat <id> <path>` | Print a file to stdout |
| `info <id>` | Show project metadata + security scan |
| `config` | Display stored credentials |

---

## 💡 Usage Examples

### Clone with options

```powershell
# Skip binary files (favicon, lockfiles)
.\lovable-cli.ps1 clone <id> --skip-binary

# Custom output directory
.\lovable-cli.ps1 clone <id> --output ./my-project

# Download only specific directories
.\lovable-cli.ps1 clone <id> --include src/,supabase/

# Combine options
.\lovable-cli.ps1 clone <id> --skip-binary --output ./myapp --include src/,public/
```

### List and read files

```powershell
# List all files
.\lovable-cli.ps1 ls <id>

# Print a source file
.\lovable-cli.ps1 cat <id> src/App.tsx

# Print environment file
.\lovable-cli.ps1 cat <id> .env
```

### Sync and inspect

```powershell
# Pull latest changes (only modified files)
.\lovable-cli.ps1 pull <id>

# Show project info + security scan
.\lovable-cli.ps1 info <id>
```

---

## ⚙️ Configuration

### Output Structure

Downloaded files are written to `./output/project-<id>/` by default, mirroring the original repo structure. A `.lovable-manifest.json` is created with metadata:

```json
{
  "id": "<project-id>",
  "ref": "<file-hash>",
  "timestamp": "2025-05-26T10:30:00Z",
  "errors": []
}
```

### Advanced Options

| Flag | Description |
|------|-------------|
| `--skip-binary` | Exclude binary files (saves space) |
| `--output <path>` | Custom download directory |
| `--include <paths>` | Comma-separated dirs to include (e.g., `src/,app/`) |
| `--throttle <ms>` | Request delay in milliseconds (default: 50) |

---

## ⚠️ Important Notes

- **Tokens expire hourly.** Re-run `set-token` to refresh your Firebase JWT.
- **Binary files** get a size stub by default (API returns metadata only). Use `--skip-binary` to exclude them entirely.
- **Rate limiting?** Increase `--throttle 200` if you hit API limits.
- **Credentials** are stored locally in `~/.lovable-cli/config.json`. Never commit this file.

---

## 🤖 For Automation

```powershell
# Batch clone multiple projects
$projects = @("id1", "id2", "id3")
$projects | ForEach-Object {
    .\lovable-cli.ps1 clone $_ --skip-binary
}

# Export all source files
.\lovable-cli.ps1 clone <id> --include src/ --output ./sources

# Pipe file content to another command
.\lovable-cli.ps1 cat <id> src/App.tsx | grep -i "export"
```

---

## 📝 License

MIT
