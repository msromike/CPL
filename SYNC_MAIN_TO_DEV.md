# Sync Main to Dev - Documentation Only

**Date:** 2025-11-12
**Purpose:** Track which documentation files need to be copied from main to dev

---

## Files to Copy from Main to Dev

### New Documentation Files (Created on Main)
- [ ] `dev_docs/RAID_COLLECTION_DEBUG_NOTES.md` - Raid join event investigation
- [ ] `dev_docs/DEBUG_SYSTEM_IMPROVEMENTS.md` - Debug category filtering design
- [ ] `dev_docs/HOTFIX_CHERRYPICK_TRACKER.md` - Updates from main hotfixes

### GitHub Copilot Configuration (New)
- [ ] `.github/copilot-instructions.md` - Core WoW/Lua guidelines
- [ ] `.github/instructions/lua-patterns.instructions.md` - Lua-specific rules
- [ ] `.github/instructions/testing.instructions.md` - In-game testing patterns
- [ ] `.github/prompts/generate-test-commands.md` - Test command generator
- [ ] `.github/prompts/review-wow-api.md` - API compatibility checker
- [ ] `.vscode/settings.json` - Copilot integration settings

### Completion Marker Files
- [ ] `COPILOT_ENV_COMPLETE.md` - Session completion marker
- [ ] `COPILOT_SETUP_COMPLETE.md` - Initial setup marker
- [ ] `dev_docs/COPILOT_CONFIGURATION.md` - Configuration summary

### Production Files to Update on Dev (if needed)
- [ ] `CURSEFORGE_DESCRIPTION.md` - Updated slash commands (after commit)
- [ ] Review `CHANGELOG.md` - Ensure dev has v1.0.4 and v1.0.5 entries

---

## Files to KEEP on Main (Production Only)
- CPL.lua
- CHANGELOG.md
- CPL.toc
- Debug.lua (commented out in TOC)
- ChattynatorIntegration.lua
- README.md
- LICENSE
- `.github/` folder (Copilot config)

---

## Files to REMOVE from Main (Dev Only)
After copying to dev, remove these from main:
- [ ] `dev_docs/RAID_COLLECTION_DEBUG_NOTES.md`
- [ ] `dev_docs/DEBUG_SYSTEM_IMPROVEMENTS.md`
- [ ] `dev_docs/HOTFIX_CHERRYPICK_TRACKER.md` (updates)
- [ ] `COPILOT_ENV_COMPLETE.md`
- [ ] `COPILOT_SETUP_COMPLETE.md`
- [ ] `dev_docs/COPILOT_CONFIGURATION.md`
- [ ] Any other `dev_docs/` files that shouldn't be in production

---

## Procedure

### Step 1: Commit Current Main Changes
```bash
git add CURSEFORGE_DESCRIPTION.md
git commit -m "Update CurseForge description with new slash commands"
git push origin main
```

### Step 2: Switch to Dev and Copy Files
```bash
git checkout dev
```

Then manually copy each file from the checklist above:
- Use file explorer or `cp` command
- Preserve directory structure (e.g., `dev_docs/`, `.github/`)

### Step 3: Commit to Dev
```bash
git add dev_docs/ .github/ .vscode/ *.md
git commit -m "Sync documentation from main: Copilot config, raid debug notes, debug improvements"
git push origin dev
```

### Step 4: Clean Up Main
```bash
git checkout main
git rm dev_docs/RAID_COLLECTION_DEBUG_NOTES.md
git rm dev_docs/DEBUG_SYSTEM_IMPROVEMENTS.md
git rm COPILOT_ENV_COMPLETE.md
git rm COPILOT_SETUP_COMPLETE.md
git rm dev_docs/COPILOT_CONFIGURATION.md
# Review dev_docs/ and remove any other dev-only files
git commit -m "Remove dev docs from main - keep production files only"
git push origin main
```

### Step 5: Verify
- [ ] Main has only production files
- [ ] Dev has all documentation
- [ ] Both branches pushed successfully
- [ ] Delete this SYNC_MAIN_TO_DEV.md file (it's done its job)

---

## Notes

- Do NOT merge code between branches (refactoring is different)
- Only copy documentation/configuration files
- Keep production code separate on each branch
- This is a one-time sync operation for this session's work
