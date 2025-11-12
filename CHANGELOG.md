# Changelog

All notable changes to CPL (Chat Player Levels) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.5] - 2025-11-12

### Added

- **Debug Command Enhancement:** `/cpl dbcheck` now supports multiple filter terms
  - Usage: `/cpl dbcheck del <name1> [name2] [name3] ...`
  - Usage: `/cpl dbcheck new <name1> [name2] [name3] ...`
  - Usage: `/cpl dbcheck old <name1> [name2] [name3] ...`
  - Each filter must be at least 3 characters
  - Matches any player name containing any of the filter substrings

### Fixed

- **Debug Mode:** Debug.lua disabled by default in production (reduces clutter for users)
  - Previous release (v1.0.4) accidentally shipped with debug enabled
  - Debug commands no longer available to end users (without them editing TOC)
  - Cleaner chat experience for typical usage
- **Raid Collection:** Added `RAID_ROSTER_UPDATE` event to improve raid member detection
  - Raid leaves now properly trigger collection
  - Debug output added to party/raid collection functions

### Known Issues

- **Raid Join Collection:** Raid members joining may not be auto-detected in all cases
  - Workaround: Target or mouseover raid members to cache their levels manually
  - Investigation ongoing for future fix

## [1.0.4] - 2025-11-11

### Fixed

- **Database Migration:** Auto-detect and migrate pre-v1.0.3 database format
  - Old format (`CPLDB.realm` structure) is automatically wiped and replaced with new format (`CPLDB.players`)
  - Fixes compatibility issues for users who installed before v1.0.3
  - Migration happens silently on first login after update
  - Establishes pattern for handling future database schema changes

## [1.0.3] - 2025-11-10

### Added

- **Database Schema Migration:** Extended player cache to support future features
  - New format stores: `level`, `class`, `source`, `trigger`, `firstSeen`, `lastSeen`, `meshShared`
  - Old format: `{level, timestamp}` → New format: `{level=X, class=Y, ...}`
  - Lazy migration: Old entries converted on-the-fly when updated
  - Backward compatible: `getLevel()` handles both formats transparently
  - Enables future class colorization and mesh protocol features

- **Debug Tools:** Added `/cpl dbcheck` command (Debug.lua only)
  - Usage: `/cpl dbcheck old [name]` or `/cpl dbcheck new [name]`
  - Displays comma-delimited dump of database entries
  - Shows summary stats: total count, first/last collection timestamps
  - Useful for verifying migration and inspecting data quality

- **Status Command:** Added `/cpl status` with contextual display modes
  - Summary mode: Player count, WHO queue depth
  - `-what` flag: Stats only (count, avg level, first/last collection timestamps)
  - `-who` flag: People-focused (last 3 learned, class breakdown with counts)
  - `-how` flag: Method-focused (collection source breakdown, mesh count, WHO queue status)
  - Name filter: `/cpl status <name>` shows substring matches with aligned level/class display
  - Replaces `/cpl cache` with more intuitive UX-driven flag semantics

### Changed

- **Unknown Level Display:** Removed `[??]` placeholder for uncached players
  - Players with unknown levels now display with no level prefix
  - Levels appear only when known: `[15] PlayerName`
  - Collection logic unchanged - still queues WHO lookups for unknown players
  - Positive UX: Focus on what CPL has learned, not what it doesn't know yet

- **Professional Init Banner:** Compact single-line format on addon load
  - Format: `Chat Player Level v1.0.3 by msromike. Type /cpl for options.`
  - Version programmatically retrieved via `GetAddOnMetadata()` (single source of truth)

- **Collection Methods:** All 6 collection points now capture class data
  - Target, mouseover, party, raid: Use `UnitClass()`
  - Guild: Extracts class from `GetGuildRosterInfo()`
  - WHO: Uses `info.classStr` from WHO results
  - Class data stored in new database format for future features

## [1.0.2] - 2025-11-09

### Fixed

- **Social Frame Popups:** Reduced MAX_WHO_ATTEMPTS from 3 to 1 to minimize Social frame popups
  - Ambiguous player names (e.g., "Bank", "Bankalt") trigger multiple WHO results, causing Social frame to pop
  - Reducing retry attempts from 3 to 1 eliminates 67% of popup spam
  - Trade-off: Slightly lower cache hit rate, but dramatically improved UX in busy zones

### Improved

- **Debug UX:** Throttled debug messages to prevent spam while maintaining educational value
  - Guild scan: Message now appears once per minute (guild events fire frequently from party/raid updates)
  - WHO throttle: Suppressed duplicate messages from OnMouseDown + OnMouseUp firing together on normal clicks
    - 200ms window catches duplicates from single clicks while preserving messages from click-and-hold events
  - Actual scan/query throttles remain unchanged, message throttling only prevents chat spam

### Changed

- **Slash Commands:** `/cpl queue` and all commands starting with 'q' now trigger queue display (e.g., `/cpl q`)
- **Timer Display:** Changed all debug timers from count-up to countdown format for better learning experience
  - WHO throttle: Shows "Next in X.Xs"
  - Guild scan throttle: Shows "Next in Xm Xs" when scan is throttled
  - Cache staleness: Shows "Stale (X.Xh overdue)" instead of "Stale X.Xh ago"
  - Countdown timers help users understand cooldown durations

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
