# Changelog

All notable changes to CPL (Chat Player Levels) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-11-08

### Fixed

- **Consistency:** Changed unknown level indicator from `[..]` to `[??]` in CPL.lua to match ChattynatorIntegration.lua
- **Documentation:** Updated CurseForge description to explain `[??]` placeholder for uncached players

### Improved

- **Performance:** Added `OnMouseUp` event hook alongside `OnMouseDown` for more frequent WHO queue processing opportunities

### Changed

- Updated CurseForge description for clarity on gradual level detection and Blizzard/Chattynator chat support

## [1.0.0] - 2025-11-07

### Added

- Initial release of CPL (Chat Player Levels)
- Automatic player level detection and display in chat channels
- Intelligent 8-hour player level caching system
- Smart WHO query system with throttling and retry logic
- Guild roster integration for instant guild member level detection
- Target and mouseover level detection
- Chattynator integration for enhanced chat addon support
- Optional debug module with visual debug frame
- Slash commands: `/cpl help`, `/cpl cache`, `/cpl channels`
- Debug commands: `/cpl debug`, `/cpl queue`, `/cpl debugframe`
- Duplicate suppression to prevent redundant WHO queries
- Configurable channel monitoring (defaults to guild, party, raid, officer, whispers, say, yell, channels 1-7)

### Technical Details

- Based on Prat-3.0's proven level caching architecture
- WHO query cooldown: 5 seconds
- Guild scan cooldown: 10 minutes
- Maximum WHO retry attempts: 3
- Cache expiry: 8 hours (28800 seconds)
- SavedVariables: CPLDB

### Known Limitations

- WHO queries are subject to WoW API throttling (5-second cooldown enforced)
- Cache does not persist between player level changes (will update on next detection)
- Debug module must be disabled by commenting out in .toc (no in-game toggle for production use)

### Credits

- Inspired by and derived from Prat-3.0 level caching system
- Compatible with Chattynator chat addon

---

## Future Plans

### Potential Features for v1.1+

- Configurable cache expiry time
- Option to disable specific channel types via slash commands
- Manual cache refresh command
- Level change notifications for cached players
- Color-coded level display (green for lower, red for higher)

---

[1.0.0]: https://github.com/msromike/CPL/releases/tag/v1.0.0
