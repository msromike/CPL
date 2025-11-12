# GitHub Copilot Configuration for CPL Addon

**Created:** 2024-11-12
**Purpose:** Leverage new Copilot features to improve development workflow and code quality

---

## 🎯 Key New Features Available

### 1. **Custom Instructions** (.github/copilot-instructions.md)
- Auto-applies to ALL chat requests in workspace
- Perfect for WoW Lua/addon-specific guidelines
- Shared across team via git

### 2. **Targeted Instructions** (*.instructions.md)
- File-specific rules using glob patterns
- Can have multiple per project
- Example: `applyTo: "**/*.lua"` for Lua-specific rules

### 3. **Workspace Index**
- GitHub can remotely index this repo for better context
- Small projects auto-indexed on first `@workspace` use
- CPL is ~20 files, perfect size for full indexing

### 4. **Prompt Files**
- Reusable commands for common tasks
- Can create slash commands like `/review-code`
- Combine with custom instructions

### 5. **Custom Chat Modes**
- Specialized assistants (e.g., "WoW API expert")
- Control which tools/context available
- Experimental but powerful

---

## 📋 Recommended Configuration for CPL

### **PHASE 1: Basic Setup (5 minutes, HIGH VALUE)**

#### Create `.github/copilot-instructions.md`

This will transform EVERY interaction by teaching Copilot about WoW addon development:

```markdown
# CPL WoW Classic Era Addon Instructions

## Project Context
- **Game:** World of Warcraft Classic Era (1.15.x)
- **Language:** Lua 5.1
- **Framework:** WoW AddOn API (Classic Era, NOT Retail)
- **Purpose:** Cross-faction communication addon using player database

## Critical WoW Classic Era API Constraints
- NO ChatFrame_MessageEventHandler (Retail only)
- ChatFrame_AddMessageEventFilter is PRIMARY chat hook
- Filter signature: `function(self, event, msg, author, ...) return filter, newMsg, newAuthor, ...`
- Modifying author parameter BREAKS hyperlinks (confirmed via testing)
- Very limited API compared to Retail - ALWAYS verify API exists in Classic
- Use Wowpedia Classic Era documentation, not Retail docs

## Code Style Guidelines
- Use tabs for indentation (WoW Lua convention)
- Prefix all globals with CPL (e.g., CPLDB, CPL_VERSION)
- Event handlers named: CPL_OnEvent, CPL_OnAddonLoaded, etc.
- Database structure: CPLDB.players[name] = {Level=N, Class="X", ...}
- Comment complex logic (especially regex patterns and Blizzard API workarounds)

## Architecture Patterns
- Core logic in CPL.lua
- Integration modules separate (ChattynatorIntegration.lua, etc.)
- Debug utilities in Debug.lua
- Database schema documented in DB_SCHEMA_MIGRATION_*.md files
- All public API in CPL namespace table

## Testing Requirements
- Must be testable in-game (no external Lua environment)
- Provide `/run` commands for quick testing when suggesting features
- Consider both Chattynator mode AND Blizzard mode
- Test with guild chat, whispers, say, yell, etc.

## Documentation Standards
- CHANGELOG.md for user-facing changes
- dev_docs/ for technical designs and handoff docs
- archive/ for old designs and deprecated code
- Include in-game test commands in feature proposals

## Common Pitfalls to Avoid
- Don't assume Retail APIs exist in Classic Era
- Don't break hyperlinks by modifying author parameter
- Don't use external libraries (WoW sandbox is isolated)
- Don't suggest regex without escaping % properly (Lua uses %, not \)
- Remember gsub uses patterns, not full regex

## Chattynator Integration
- Chattynator uses custom OnEvent hooking, NOT ChatFrame_AddMessageEventFilter
- Our integration: Chattynator.API.AddModifier for level prefixes
- Regex pattern: `(|Hplayer:([^:]+)[^|]*|h)(|cff%x%x%x%x%x%x)([^|]+)|r(|h)`
- This works perfectly in Chattynator mode, DON'T touch it

## When Suggesting Changes
1. Check if API exists in Classic Era via Wowpedia
2. Provide in-game test command (e.g., `/run` snippet)
3. Consider both Chattynator and Blizzard rendering modes
4. Test if hyperlinks remain clickable
5. Document in appropriate dev_docs/ file if architectural
```

**Implementation:**
```powershell
# Create the file
mkdir .github -Force
# Then paste the content above into .github/copilot-instructions.md
```

**Expected Impact:**
- ✅ Copilot stops suggesting Retail-only APIs
- ✅ Code follows WoW addon conventions automatically
- ✅ Gets context about Chattynator integration
- ✅ Understands testing constraints
- ✅ Knows to verify Classic Era API availability

---

### **PHASE 2: Targeted Instructions (10 minutes, MEDIUM VALUE)**

Create `.github/instructions/lua-patterns.instructions.md`:

```markdown
---
applyTo: "**/*.lua"
description: "Lua-specific coding rules for WoW addons"
---

# Lua Pattern Matching Rules

## Lua Patterns vs Regex
- Lua uses `%` for escaping, not `\`
- Character classes: `%a` (letters), `%d` (digits), `%s` (space), `%w` (alphanumeric)
- Magic characters: `( ) . % + - * ? [ ] ^ $`
- Repetition: `*` (0+), `+` (1+), `-` (lazy 0+), `?` (0-1)

## WoW Hyperlink Format
- Player link: `|Hplayer:Name:LineID|h[DisplayName]|h`
- With color: `|Hplayer:Name:LineID|h|cffCOLORName|r|h`
- Item link: `|Hitem:ItemID:...|h[ItemName]|h`

## String Manipulation Best Practices
- Use `string.format()` for readability
- Cache `string.gsub` results if used repeatedly
- Use `string.find()` before `string.gsub()` if pattern might not match
- Remember gsub returns (newString, numReplacements)

## Performance Tips
- Minimize table creation in hot paths (event handlers)
- Cache WoW API calls that don't change (UnitName, GetRealmName)
- Use local functions for frequently called code
```

Create `.github/instructions/testing.instructions.md`:

```markdown
---
applyTo: "test_*.txt,*_test.lua"
description: "Testing guidelines for in-game verification"
---

# In-Game Testing Guidelines

## Test Command Format
- Use `/run` for quick tests
- Use `/script` for multiline (but prefer `/run` for portability)
- Print debug info: `/run print("Value:", variable)`
- Reload UI: `/reload` or `/console reloadui`

## Event Testing Pattern
```lua
/run local frame = CreateFrame("Frame"); frame:RegisterEvent("EVENT_NAME"); frame:SetScript("OnEvent", function(self, event, ...) print(event, ...); end)
```

## Chat Filter Testing Pattern
```lua
/run local function test(self, event, msg, author, ...)
  print("FILTER:", event, msg, author)
  return false, "[TEST] " .. msg, author, ...
end
ChatFrame_AddMessageEventFilter('CHAT_MSG_SAY', test)
/say Test message
```

## Database Inspection
- `/run DevTools_Dump(CPLDB)` (if DevTools installed)
- `/run for k,v in pairs(CPLDB.players) do print(k, v.Level, v.Class) end`

## Always Provide
1. Setup command (register filter, create frame, etc.)
2. Test command (generate event or trigger condition)
3. Expected output (what should print or appear in chat)
4. Cleanup command (remove filter, unregister events) if needed
```

**Implementation:**
```powershell
mkdir .github\instructions -Force
# Then create the two files above
```

---

### **PHASE 3: Workspace Indexing (2 minutes, HIGH VALUE)**

Enable GitHub remote indexing for better `@workspace` queries:

1. **Ensure settings enabled:**
   - Open VS Code Settings (Ctrl+,)
   - Search: `github.copilot.chat.codeGeneration.useInstructionFiles`
   - Ensure: ✅ Enabled

2. **Trigger initial index:**
   - Open Command Palette (Ctrl+Shift+P)
   - Run: `Build Remote Workspace Index`
   - OR: Just use `@workspace` in chat once (auto-indexes)

3. **Verify indexing status:**
   - Check Copilot icon in status bar (bottom right)
   - Should show "Indexed" after a few seconds
   - CPL is ~20 files, indexes almost instantly

**Expected Impact:**
- ✅ `@workspace` queries understand full codebase structure
- ✅ Can ask "where is level detection logic?" and get precise answer
- ✅ Better code suggestions based on existing patterns
- ✅ Faster semantic search across all addon files

---

### **PHASE 4: Prompt Files (Optional, 15 minutes, MEDIUM VALUE)**

Create reusable commands for common dev tasks:

**File:** `.github/prompts/review-wow-api.md`
```markdown
---
description: "Check if proposed code uses Classic Era-compatible APIs"
---

# Review WoW API Compatibility

Review the selected code or current file and check for:

1. **Retail-only APIs:** Verify every WoW API call exists in Classic Era 1.15.x
   - Use Wowpedia Classic Era docs: https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
   - Flag any Retail-only APIs (e.g., C_*, ChatFrame_MessageEventHandler)

2. **Hyperlink Handling:** Check if code modifies player names or hyperlinks
   - Author parameter modification breaks hyperlinks (known limitation)
   - Suggest regex-based post-processing instead

3. **Lua Patterns:** Verify pattern escaping uses `%`, not `\`

4. **Global Pollution:** Check all functions/vars are properly namespaced with CPL prefix

Provide a checklist of issues found with line numbers and suggested fixes.
```

**File:** `.github/prompts/generate-test-commands.md`
```markdown
---
description: "Generate in-game test commands for a feature"
---

# Generate In-Game Test Commands

For the selected code or feature, generate:

1. **Setup command:** `/run` snippet to initialize (register event, add filter, etc.)
2. **Test command:** How to trigger the feature (e.g., `/say Test`, whisper someone)
3. **Expected output:** What should appear in chat or be printed
4. **Inspection command:** How to verify database changes (e.g., `/run print(CPLDB.xyz)`)
5. **Cleanup command:** How to remove test hooks (if needed)

Format as copyable commands with explanations.
```

**Usage:**
- Select code → Chat → `@prompts` → Choose prompt
- Or: Type `#file:review-wow-api.md` in chat

---

## 🚀 Quick Win: Generate Initial Instructions

VS Code can auto-generate `.github/copilot-instructions.md` based on existing code:

1. Open Command Palette (Ctrl+Shift+P)
2. Run: `Chat: Generate Instructions`
3. Review generated content
4. Merge with WoW-specific guidelines above

This provides a baseline, then enhance with WoW Classic Era context.

---

## 📊 Time Investment vs. Value

| Phase | Time | Value | ROI |
|-------|------|-------|-----|
| **Phase 1: Basic Instructions** | 5 min | HIGH | ⭐⭐⭐⭐⭐ |
| **Phase 3: Workspace Index** | 2 min | HIGH | ⭐⭐⭐⭐⭐ |
| **Phase 2: Targeted Instructions** | 10 min | MEDIUM | ⭐⭐⭐ |
| **Phase 4: Prompt Files** | 15 min | MEDIUM | ⭐⭐⭐ |

**RECOMMENDATION:** Do Phases 1 & 3 NOW (7 minutes total, massive impact).
Phases 2 & 4 can wait until you notice repetitive questions.

---

## 💡 Immediate Benefits You'll See

After Phase 1 + 3:

1. **Stop explaining WoW API limitations every session**
   - "Remember, Classic Era doesn't have X" → AUTOMATIC

2. **Get accurate code suggestions**
   - Copilot will suggest `ChatFrame_AddMessageEventFilter`, not Retail APIs

3. **Better @workspace queries**
   - "Where do we cache player levels?" → Instant accurate answer
   - "How does Chattynator integration work?" → Shows exact file/function

4. **Correct Lua patterns automatically**
   - Will use `%` not `\` in regex patterns
   - Suggests proper hyperlink patterns

5. **Context-aware refactoring**
   - Knows to check both Chattynator and Blizzard modes
   - Understands CPLDB structure without explanation

---

## 🔧 Settings to Enable

Add to workspace `.vscode/settings.json`:

```json
{
  // Enable custom instructions
  "github.copilot.chat.codeGeneration.useInstructionFiles": true,

  // Enable workspace context
  "github.copilot.enable": {
    "*": true,
    "plaintext": false,
    "markdown": true,
    "lua": true
  },

  // Use nested AGENTS.md if you want folder-specific instructions (experimental)
  "chat.useNestedAgentsMdFiles": false,

  // Instruction file locations (defaults are fine)
  "chat.instructionsFilesLocations": [
    ".github/instructions"
  ]
}
```

---

## 📈 Measuring Impact

**Before Custom Instructions:**
- "What WoW API should I use for X?" → 3-4 clarifying questions
- Suggests Retail APIs, you correct, repeat
- Have to explain Chattynator integration each session

**After Custom Instructions:**
- "Add feature X" → Correct API first try
- Automatically checks Classic Era compatibility
- Includes in-game test commands
- Respects both Chattynator and Blizzard modes

**Estimated Time Saved:** 5-10 minutes per session, every session

---

## 🎓 Learning Curve

- **Phase 1:** Zero learning curve (just create file)
- **Phase 3:** One command to run
- **Phase 2:** Need to learn glob patterns (5 min tutorial)
- **Phase 4:** Need to learn prompt file format (10 min tutorial)

**Total time to master:** ~20 minutes
**Time saved per week:** 30-60 minutes (assuming 6 coding sessions)

---

## ✅ Action Plan

1. **NOW** (5 min): Create `.github/copilot-instructions.md` with WoW-specific context
2. **NOW** (2 min): Run `Build Remote Workspace Index` command
3. **Test it** (1 min): Ask chat "What WoW Classic APIs do we use for chat filtering?"
4. **Verify** (1 min): Response should mention ChatFrame_AddMessageEventFilter, NOT Retail APIs
5. **Later** (10 min): Add targeted Lua and testing instructions if you want
6. **Later** (15 min): Create prompt files for common workflows if you want

---

## 📚 Resources

- [Custom Instructions Docs](https://code.visualstudio.com/docs/copilot/customization/custom-instructions)
- [Workspace Context Docs](https://code.visualstudio.com/docs/copilot/workspace-context)
- [Prompt Files Docs](https://code.visualstudio.com/docs/copilot/customization/prompt-files)
- [Community Examples](https://github.com/github/awesome-copilot)

---

## 🔄 Maintenance

- **Update instructions** when you discover new WoW API limitations
- **Add to instructions** when you explain the same thing 3+ times
- **Re-index workspace** when structure changes significantly (automatic)
- **Review prompt files** monthly to add new common tasks

**Instructions files are code** - commit them to git, review in PRs, treat as documentation.
