# VS Code grep_search Tool Troubleshooting Guide

## Problem: grep_search returns "No matches found" for files you know exist

This document tracks solutions for when AI tools (Copilot, Claude, etc.) can't find files using the `grep_search` tool in VS Code.

---

## Quick Diagnosis Checklist

Run through these checks in order:

### ✅ 1. Verify the file actually contains your search term
```powershell
Select-String -Pattern "YOUR_SEARCH_TERM" -Path "path\to\file.ext"
```
If this finds it but grep_search doesn't, continue below.

---

### ✅ 2. Check `.gitignore` (MOST COMMON ISSUE)

**Problem:** VS Code's default `search.useIgnoreFiles: true` makes grep skip files in `.gitignore`

**Check:**
```bash
cat .gitignore
```

**Solution:** Add to `.vscode/settings.json`:
```json
{
    "search.useIgnoreFiles": false
}
```

**Why this happens:**
- You gitignore reference code (Prat, libraries, etc.) to keep it out of version control
- VS Code respects this for search by default
- AI grep tools silently fail on these files

---

### ✅ 3. Check `Lua.workspace.ignoreDir` settings

**Problem:** Lua language server ignore settings **WILL BLOCK AI ASSISTANT GREP/SEARCH**

**Check:** `.vscode/settings.json`
```json
"Lua.workspace.ignoreDir": [
    "archive/",
    "Prat-3.0/",  // ← This blocks AI grep_search tool entirely
    "Ace3/"
]
```

**IMPORTANT:** Even though this setting is meant for Lua linting/intellisense, it also prevents AI assistants (Copilot, Claude, etc.) from using grep_search in these directories. This is a VS Code limitation.

**Solution:**
- **Option 1:** Remove directories from `Lua.workspace.ignoreDir` if you need AI to search them
- **Option 2:** Accept that you'll see linter errors for those directories, but AI can search them
- **Option 3:** Only add directories you truly never need to search (like `archive/`)

**Trade-off:**
- If you exclude: No linter errors in those folders, BUT AI cannot search them
- If you include: AI can search them, BUT you see all their linter errors

**Recommendation:** Only use `Lua.workspace.ignoreDir` for directories you absolutely never need AI to search (archives, build outputs, etc.). For reference code like Prat/Chattynator, accept the linter errors so AI can still help you search and understand that code.

---

### ✅ 4. Verify glob pattern syntax

**Invalid patterns that fail silently:**
```json
❌ "includePattern": "src/**|test/**"           // Pipe not supported
❌ "includePattern": "src/*/file.lua"           // May not work as expected
```

**Valid patterns:**
```json
✅ "includePattern": "**/*.lua"                 // All Lua files
✅ "includePattern": "src/**,test/**"           // Comma-separated
✅ "includePattern": "src/{folder1,folder2}/**" // Brace expansion
✅ "includePattern": "path/to/specific/file.lua" // Specific file
```

---

### ✅ 5. Check VS Code's `files.exclude` and `search.exclude` settings

**Check:** `.vscode/settings.json` or User Settings
```json
"files.exclude": {
    "**/.git": true,
    "Prat-3.0/": true  // ← This would hide files
},
"search.exclude": {
    "**/node_modules": true,
    "Prat-3.0/": true  // ← This blocks search
}
```

**Solution:** Remove directories you need to search

---

### ✅ 6. Verify workspace folder scope

**Problem:** Files must be in a workspace folder to be searchable

**Check:** VS Code Explorer sidebar - is the directory visible?

**Solution:**
- File → Add Folder to Workspace
- Or open the parent directory as workspace

---

### ✅ 7. Restart Lua Language Server

After changing settings:
- Press `Ctrl+Shift+P`
- Run: "Lua: Restart Server"
- Or: "Developer: Reload Window"

---

## Our Specific Issue (CPL Project)

**Symptoms:**
- `grep_search` couldn't find `GUILD_ROSTER_UPDATE` in `Prat-3.0/modules/PlayerNames.lua`
- PowerShell `Select-String` found it instantly
- File exists, is readable, contains the search term

**Root cause:**
`.gitignore` had `Prat-3.0/` and VS Code defaulted to `search.useIgnoreFiles: true`

**Fix:**
Added to `.vscode/settings.json`:
```json
{
    "search.useIgnoreFiles": false,
    "Lua.workspace.ignoreDir": [
        "archive/"  // Removed Prat-3.0 and Ace3
    ]
}
```

**Why this setup:**
- Keep Prat-3.0 in `.gitignore` (don't track third-party code)
- Allow VS Code search/grep to access it (need it for reference)
- Remove from Lua workspace ignore (allow analysis for code reuse)

---

## Debugging Commands

### Test if file is being ignored:
```powershell
# From workspace root
Select-String -Pattern "SEARCH_TERM" -Path "path\to\file"
```

### Check current directory:
```powershell
pwd
```

### List VS Code workspace storage (cache locations):
```powershell
Get-ChildItem "$env:APPDATA\Code\User\workspaceStorage"
```

---

## Prevention

### Standard `.vscode/settings.json` for projects with reference code:
```json
{
    "search.useIgnoreFiles": false,
    "Lua.workspace.ignoreDir": [
        "archive/"
    ],
    "files.exclude": {
        "**/.git": true
    }
}
```

### Keep reference code in `.gitignore`:
```gitignore
# Third-party reference code (search-enabled, not tracked)
Prat-3.0/
Ace3/
ThirdPartyLib/

# Actual junk (hidden and not searched)
archive/
*.tmp
```

---

## Time Saved

**Without this guide:** 2+ days of frustration
**With this guide:** 20 minutes to fix

Keep this in every project workspace with reference code.
