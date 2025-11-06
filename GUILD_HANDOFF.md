# Guild Roster Scanning - Implementation Handoff

## Status

Ready to implement guild member level caching. All prerequisite systems working.

## What Works Now

- ✅ Target/mouseover detection (updateTarget, updateMouseOver)
- ✅ Party/raid detection (updateParty, updateRaid)
- ✅ WHO query system with queue and cache expiry
- ✅ Chat monitoring for unknown players
- ✅ 2-hour cache expiry with level 60 immutability
- ✅ WHO spam suppression filter

## What's Missing

Guild roster scanning - bulk cache all guild members on login/roster changes.

## The Task

Add `updateGuild()` function following Prat-3.0 pattern but with native WoW API (no Ace).

## Key Technical Facts

**Guild Roster is FAST:**

- `GuildRoster()` requests full roster blob from server (async)
- Server responds with ALL members at once
- `GUILD_ROSTER_UPDATE` event fires when data ready
- Iterating 500+ members via `GetGuildRosterInfo(i)` is < 100ms (memory reads)

**NOT like WHO queries:**

- WHO = 1 query per player (500 queries = 8+ minutes)
- Guild = 1 request for all 500 (instant after data loads)

## Implementation Steps

1. Add throttle variables (`lastGuildScan`, `guildScanThrottle = 900`)
2. Create `updateGuild()` function with throttle check
3. Loop `GetNumGuildMembers()`, call `GetGuildRosterInfo(i)`, cache via `addName()`
4. Register `GUILD_ROSTER_UPDATE` event
5. Add event handler to call `updateGuild()`
6. In `ADDON_LOADED`, check `IsInGuild()` and call `GuildRoster()` to request initial data
7. Update lint configs with guild API globals

## Native WoW APIs Needed

```lua
IsInGuild()              -- Check if in guild
GuildRoster()            -- Request roster from server
GetNumGuildMembers()     -- Get count
GetGuildRosterInfo(i)    -- Get member data: name, _, _, level, ...
```

## Reference

See `Prat-3.0/modules/PlayerNames.lua` lines 1393-1418 for working implementation.
Our version is simpler - no gate flag needed, just throttle event spam.

## Testing

After `/reload`, guild members should appear in `/cpl cache` output automatically.
