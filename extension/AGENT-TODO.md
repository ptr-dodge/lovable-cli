# Agent Tasks: Lovable.dev Chrome Extension

**This file lists modular agent-friendly tasks for bootstrapping and improving the browser extension. Agents/contributors: check off tasks as you complete them!**

---

## 0. Initial Setup

- [ ] Copy the extension skeleton into `/extension`
- [ ] Add a starter `manifest.json` (see below)
- [ ] Add a simple `popup.html` with “Hello, world!”
- [ ] Add sample icons (16/48/128 px, placeholder allowed)
- [ ] Validate loading unpacked in Chrome

---

## 1. Minimal Working Extension

- [ ] `contentScript.js` should detect when running on lovable.dev
- [ ] `background.js` should handle messages
- [ ] `popup.js` should send test message to content script

---

## 2. Workspace List & Download MVP

- [ ] Extract user tokens (with permission)
- [ ] List discoverable Lovable workspaces
- [ ] Download selected workspace as .zip using JSZip (in libs/ or CDN)
- [ ] Show download status/results in popup

---

## 3. Options Page

- [ ] Implement `/options/options.html` UI
- [ ] Add controls to configure download folder, integrations, etc.

---

## 4. Documentation

- [ ] Update `README.md` with usage, screenshot, and contribution guide
- [ ] Add architecture diagram (optional, for bonus clarity)

---

## Reference: manifest.json (starter)

```json
{
  "manifest_version": 3,
  "name": "Lovable.dev Workspace Downloader",
  "version": "0.1",
  "description": "Download and zip Lovable.dev workspaces directly from the browser.",
  "permissions": ["scripting", "storage", "downloads"],
  "host_permissions": ["https://lovable.dev/*", "https://api.lovable.dev/*"],
  "background": {
    "service_worker": "src/background.js"
  },
  "icons": {
    "16": "icons/icon16.png",
    "48": "icons/icon48.png",
    "128": "icons/icon128.png"
  },
  "action": {
    "default_popup": "src/popup/popup.html",
    "default_icon": "icons/icon48.png"
  },
  "options_ui": {
    "page": "src/options/options.html",
    "open_in_tab": true
  },
  "content_scripts": [
    {
      "matches": [
        "https://lovable.dev/*"
      ],
      "js": ["src/contentScript.js"]
    }
  ]
}
```

---

**Agents:** See each check item above, and consult `/extension/README.md` for setup and workflow. Commit improvements incrementally for maximum collaboration!
