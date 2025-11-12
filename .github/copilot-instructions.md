# CPL WoW Classic Era Addon Instructions

## Project Context
- **Game:** World of Warcraft Classic Era (1.15.x)
- **Language:** Lua 5.1
- **Framework:** WoW AddOn API (Classic Era, NOT Retail)
- **Purpose:** Creates database of player levels detected by various methods and prepends the player level to the player name, or to the msg payload if prepend to name not possible

## Critical WoW Classic Era API Constraints
- **Modern Classic uses the SAME client as Retail** - architecture is nearly identical
- Many APIs previously "Retail-only" may now exist in Classic Era clients
- Legacy Wowpedia/documentation often reflects old split - DO NOT TRUST without testing
- **BEST PRACTICE:** If a Retail API seems useful, TEST IT in-game first before assuming unavailable
- Confirmed working: ChatFrame_AddMessageEventFilter
- Filter signature: `function(self, event, msg, author, ...) return filter, newMsg, newAuthor, ...`
- Always provide `/run` test commands to verify API existence and behavior

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
- **DON'T assume Retail APIs are unavailable** - modern Classic shares the Retail client
- **DON'T trust legacy documentation** - Wowpedia often reflects old pre-merge split
- **DO test APIs in-game** with `/run` commands before dismissing as "Retail-only"
- Don't use external libraries (WoW sandbox is isolated)
- Don't suggest regex without escaping % properly (Lua uses %, not \)
- Remember gsub uses patterns, not full regex
- When uncertain about API availability: provide test command, don't speculate

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
