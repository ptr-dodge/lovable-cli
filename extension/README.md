# Lovable.dev Downloader Chrome Extension

This is a **work-in-progress** Chrome extension companion for lovable-cli. It let’s you download/zips any Lovable.dev workspace right from your browser.

---

## 🚩 Quick Instructions

### How to load the extension (unpacked):

1. In Chrome, open `chrome://extensions/`
2. Enable **Developer Mode** (top-right)
3. Click **Load unpacked**
4. Select the `extension/` folder in this repo

### Folder Structure

```
extension/
  manifest.json
  src/
    background.js
    contentScript.js
    popup/
      popup.html
      popup.js
      popup.css
    options/
      options.html
      options.js
      options.css
  icons/
    icon16.png
    icon48.png
    icon128.png
```

### Development Goals

- 🟢 Discover Lovable.dev credentials (Firebase JWT, cookie) from your session (with your consent)
- 🟢 List your workspaces and files
- 🟢 Download workspaces as zipped folders

### Contributing

- PRs very welcome!
- All code in `/extension` is self-contained and does not affect the CLI.
- See the issue tracker for tasks, and our `./AGENT-TODO.md` for ready-to-take assignments.

---

## Future Ideas

- Support additional AI/online code platforms
- Options page for managing services, tokens, and batch downloads
- Safe storage and batch export/import

---
