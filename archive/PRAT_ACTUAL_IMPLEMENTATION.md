# Prat Level Display Analysis - Actual Implementation

## How Prat Actually Works (Based on Code Review)

### Configuration Discovery
- **PlayerNames module**: Present but `keep = false` by default
- **No persistent data**: SavedVariables contains no level cache because `keep = false`
- **Runtime only**: Levels displayed via runtime cache + real-time API calls

### Actual Data Flow
1. **Runtime Cache**: `self.Levels[player] = level` (memory only)
2. **Event-Driven Collection**: Guild/friends/party/target events populate cache
3. **Per-Message Lookup**: Fast hash table lookup `self:getLevel(player)`
4. **LibWho Fallback**: If cache miss, query server via LibWho-2.0
5. **No Persistence**: Data lost on logout due to `keep = false`

### Storage Format (If Enabled)
```lua
Prat3DB.namespaces.Prat_PlayerNames.realm[realmname].levels = {
  ["playername"] = 25,
  ["otherguy"] = 60
}
```

### Key Insight for CPL
Prat achieves good level display with **runtime caching only**. Persistent storage is optional and disabled by default. Our simpler approach is validated - we don't need complex persistent caching to be effective.

### Display Integration
- **Hook**: `AddMessage` on chat frames via `PRE_ADDMESSAGE` callback
- **Format**: `message.PLAYERLEVEL = CLR:Level(tostring(level), level, Name, class)`
- **Condition**: Only if `self.db.profile.level = true`