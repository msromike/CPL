# Prat Player Level Caching Method - Reference Guide

## Overview
Prat achieves high success rates for player level display by maintaining a comprehensive, persistent database of player information collected from multiple WoW API sources.

## Core Architecture

### 1. Multi-Tier Data Storage
- **Runtime Cache**: `self.Levels[player:lower()]` - Fast lookup for current session
- **Persistent Database**: `self.db.realm.levels[player:lower()]` - Cross-session storage
- **Fallback Chain**: Runtime → Persistent → LibWho query

### 2. Data Collection Sources

#### A. Guild Members (`updateGuild()`)
- Triggered by: `GUILD_ROSTER_UPDATE` event
- Uses: `C_GuildInfo.GuildRoster()` or `GuildRoster()`
- Provides: All guild member levels automatically

#### B. Friends List (`updateFriends()`)
- Triggered by: `FRIENDLIST_UPDATE` event
- Uses: `GetFriendInfo(i)` for each friend
- Provides: Friend levels when online

#### C. Group Members (`updateGroup()`)
- Triggered by: `GROUP_ROSTER_UPDATE` event
- Uses: `UnitLevel("party1")`, `UnitLevel("raid1")`, etc.
- Provides: All party/raid member levels

#### D. Player Self (`updatePlayer()`)
- Triggered by: `PLAYER_LEVEL_UP` event
- Uses: `UnitLevel("player")`
- Updates: Own level changes

#### E. Target/Mouseover
- Triggered by: `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT`
- Uses: `UnitLevel("target")`, `UnitLevel("mouseover")`
- Provides: Opportunistic level collection

#### F. LibWho-2.0 Integration
- Fallback when no cached data exists
- Queries server for unknown players
- Timeout-based with smart throttling

### 3. Key Functions

#### `addName(Name, Server, Class, Level, SubGroup, Source)`
- Central function for storing player data
- Handles cross-realm players (Server suffix)
- Implements save policies (friends/guild vs others)
- Triggers UI updates when data changes

#### `getLevel(player)`
```lua
return self.Levels[player:lower()] or
       self.db.realm.levels[player:lower()] or
       self.db.realm.levels[player]
```

#### `GetData(player, frame)`
- Main lookup function for level display
- Tries cache first, then LibWho as fallback
- Returns class, level, subgroup data

### 4. Event-Driven Updates
```lua
self:RegisterEvent("FRIENDLIST_UPDATE", "updateFriends")
self:RegisterEvent("GUILD_ROSTER_UPDATE", "updateGuild")
self:RegisterEvent("GROUP_ROSTER_UPDATE", "updateGroup")
self:RegisterEvent("PLAYER_LEVEL_UP", "updatePlayerLevel")
self:RegisterEvent("PLAYER_TARGET_CHANGED", "updateTarget")
self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "updateMouseOver")
```

### 5. Level Display Integration
- Registers message item: `Prat.RegisterMessageItem("PLAYERLEVEL", "PREPLAYERDELIM", "before")`
- Format function adds level to chat: `message.PLAYERLEVEL = CLR:Level(tostring(level), level, Name, class)`
- Controlled by user option: `self.db.profile.level`

## Implementation Strategy for CPL

### Phase 1: Basic Multi-Source Caching
1. Implement guild roster scanning
2. Add friends list monitoring
3. Add party/raid member tracking
4. Maintain persistent database

### Phase 2: Enhanced Collection
1. Add target/mouseover collection
2. Implement LibWho-2.0 integration
3. Add smart query throttling

### Phase 3: Optimization
1. Implement data retention policies
2. Add cross-session persistence
3. Optimize lookup performance

## Key Insights
- **Success comes from breadth**: Multiple data sources ensure high hit rates
- **Persistence matters**: Cross-session storage builds comprehensive database over time
- **Event-driven**: Passive collection is more efficient than active querying
- **Fallback strategy**: LibWho provides server queries when cache misses occur

## Files Referenced
- `Prat-3.0/modules/PlayerNames.lua` (lines 1100-1700)
- Key functions: `addName()`, `getLevel()`, `GetData()`, `FormatPlayer()`