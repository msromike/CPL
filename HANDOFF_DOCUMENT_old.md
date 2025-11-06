# CPL Development Handoff Document
**Date:** November 5, 2025
**Context:** ChattyNator Integration Project - Professional-grade level detection system

## Project Status & Mission

### Core Mission
Building a **LEGENDARY QUALITY** level detection addon for integration with ChattyNator (created by "the guru of WoW addons"). Code must be **TIGHT and UNDERSTANDABLE** because the hope is the guru will see how awesome this is and integrate it into ChattyNator.

**NO AMATEUR MISTAKES ALLOWED** - This is for a legend in the WoW addon community.

### Current State
- ✅ **Repository cleaned up** - All experimental/planning files archived
- ✅ **7 core detection functions working** (Target, MouseOver, Party, Raid, WHO, Guild)
- ✅ **Modern API integration** - Using C_FriendList APIs (Classic Era 2025+)
- ✅ **Extensible slash command system** - One-line additions for new commands
- ✅ **Chat hook system implemented** - Currently logging channel names to console
- ❌ **MAJOR ISSUE DISCOVERED** - Hard-coded assumptions in channel system

## Critical Issue Just Discovered

### The Problem
**Hard-coded channel names** in `CPL.channelConfig` - Classic amateur mistake that shows poor understanding of dynamic systems:

```lua
-- WRONG - Hard-coded assumptions
CPL.channelConfig = {
    [1] = {enabled = true, name = "General"},        -- ASSUMPTION
    [2] = {enabled = true, name = "Trade"},          -- ASSUMPTION
    [5] = {enabled = true, name = "LocalDefense"}    -- TOTALLY WRONG!
}
```

**Reality from testing:**
- Channel 5 is actually "LookingForGroup", not "LocalDefense"
- Channel names vary by server/realm
- We're displaying wrong names in console output

### Why This Is Embarrassing
This is exactly the kind of **"it kind of works can you please help me be better"** mistake that makes the guru facepalm. Shows:
- Untested assumptions
- Poor dynamic data handling
- Amateur hour coding
- Asking guru to fix our sloppy work

## Technical Architecture (Current)

### File Structure
```
CPL/
├── CPL.lua (main addon file - 273 lines)
├── CPL.toc (addon manifest)
├── CPL_reference.lua (has working chat hooks we can reference)
├── Prat-3.0/ (reference implementation - ignored by git)
├── Ace3/ (dependencies - ignored by git)
└── archive/ (old planning docs, experimental code)
```

### Core Systems Working
1. **Hash-table caching** - `CPL.Levels[name:lower()]` for O(1) lookup
2. **Persistent storage** - `CPLDB` saved variables
3. **WHO system** - Modern C_FriendList APIs, event-driven
4. **Debug system** - Unified `CPL:addName()` output format
5. **Extensible commands** - Table-driven slash system

### Current Chat System (BROKEN)
```lua
-- Chat message processing function
local function OnChannelChat(self, event, msg, author, language, channelString, target, flags, unknown, channelNumber, channelName, ...)
    -- Check if this channel is enabled
    if CPL.channelConfig[channelNumber] and CPL.channelConfig[channelNumber].enabled then
        -- For now: just log names to console
        print("CPL CHAT - Channel " .. channelNumber .. " (" .. CPL.channelConfig[channelNumber].name .. "): " .. author)
    end
    return false -- Pass through unchanged
end
```

**Issues:**
- Uses hard-coded `.name` instead of real `channelName`
- Should be: `(" .. (channelName or "Unknown") .. "): " .. author)`

## Next Steps for New Claude

### Immediate Priority (Fix Hard-Coding)
1. **Analyze entire codebase** for hard-coded assumptions
2. **Fix channel system** to use dynamic `channelName` data
3. **Remove all guesswork** - use only real game data
4. **Test thoroughly** before showing any code

### Phase 1: Queue Building (In Progress)
- ✅ Console logging working (but names wrong)
- ⏳ Next: Add to persistent queue storage
- ⏳ Next: Add duplicate checking
- ⏳ Next: Add timestamp management

### Phase 2: WHO Processing (Mouse-Driven)
- Use existing `CPL:testWho()` function (works perfectly)
- Trigger on `PLAYER_TARGET_CHANGED` events
- Process one queue item per mouse click
- Respect hardware event requirement (guru's wisdom)

### Phase 3: ChattyNator Integration
- Clean API documentation
- Integration examples
- Professional code comments
- Zero assumptions, all dynamic

## Code Quality Standards

### What The Guru Expects
- **No hard-coded assumptions**
- **Dynamic data handling**
- **Thoroughly tested code**
- **Clean, readable architecture**
- **Professional documentation**
- **Self-explanatory systems**

### What NOT To Do
- ❌ Hard-code channel names/numbers
- ❌ Make assumptions about server configurations
- ❌ Present untested code
- ❌ Ask for help with basic mistakes
- ❌ Show amateur debugging practices

## Current Working Commands
```
/cpl debug  - Toggle debug mode
/cpl cache  - Show cached players
/cpl who <name> - Test WHO query
/cpl help   - Show commands
```

## Test Environment
- **Server:** Classic Era (2025+)
- **Location:** Orgrimmar (active Trade/General/LFG chat)
- **Channels Active:** 1, 2, 5 (but names are dynamic!)
- **WHO System:** Modern C_FriendList APIs confirmed working

## Key Insight from Guru
**WHO queries require hardware events** - timer-based automation won't work. Must trigger WHO on actual user interactions (mouse clicks, key presses). Current approach of using `PLAYER_TARGET_CHANGED` is correct.

## Repository State
- **Branch:** main
- **Commits:** 11 total, all progress documented
- **Status:** Clean, all experimental code archived
- **Ready for:** Professional development phase

---

**Remember:** This is for integration with ChattyNator by a WoW addon legend. Code quality must be **flawless**. No shortcuts, no assumptions, no amateur mistakes. Get it RIGHT.