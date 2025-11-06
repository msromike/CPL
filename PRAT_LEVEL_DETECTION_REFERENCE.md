# PRAT Level Detection System - Implementation Reference

## Overview

7 core functions discovered in Prat that collect player level data from different sources. Each function caches levels using `addName()` for later display in chat.

---

## FUNCTION REFERENCE

### 1. **updateTarget()** - Target Level Detection ⭐ START HERE

- **File**: `Prat-3.0/modules/PlayerNames.lua`
- **Line**: ~1445
- **Regex Search**: `function module:updateTarget\(\)`
- **WoW API**: `UnitLevel("target")`, `UnitName("target")`, `UnitClass("target")`
- **Event Trigger**: PLAYER_TARGET_CHANGED
- **Test Method**: Target different level players, verify cache

### 2. **updateMouseOver()** - Mouseover Level Detection

- **File**: `Prat-3.0/modules/PlayerNames.lua`
- **Line**: ~1455
- **Regex Search**: `function module:updateMouseOver\(event\)`
- **WoW API**: `UnitLevel("mouseover")`, `UnitName("mouseover")`, `UnitClass("mouseover")`
- **Event Trigger**: UPDATE_MOUSEOVER_UNIT
- **Test Method**: Hover over players, verify cache

### 3. **updateParty()** - Party Member Detection

- **File**: `Prat-3.0/modules/PlayerNames.lua`
- **Line**: ~1430
- **Regex Search**: `function module:updateParty\(\)`
- **WoW API**: `UnitLevel("party1")`, `UnitName("party1")`, `UnitClass("party1")`
- **Event Trigger**: GROUP_ROSTER_UPDATE
- **Test Method**: Join party, verify party member levels cached

### 4. **updateGuild()** - Guild Member Detection

- **File**: `Prat-3.0/modules/PlayerNames.lua`
- **Line**: ~1398
- **Regex Search**: `function module:updateGuild\(\)`
- **WoW API**: `GetGuildRosterInfo(i)` - bulk guild data
- **Event Trigger**: GUILD_ROSTER_UPDATE
- **Test Method**: Check guild tab, verify all guild levels cached

### 5. **updateRaid()** - Raid Member Detection

- **File**: `Prat-3.0/modules/PlayerNames.lua`
- **Line**: ~1415
- **Regex Search**: `function module:updateRaid\(\)`
- **WoW API**: `GetRaidRosterInfo(i)`, `UnitName("raid1")`
- **Event Trigger**: GROUP_ROSTER_UPDATE
- **Test Method**: Join raid, verify raid member levels cached

### 6. **updateWho()** - WHO Query Results Processing ⭐ KEY FUNCTION

- **File**: `Prat-3.0/modules/PlayerNames.lua`
- **Line**: ~1470
- **Regex Search**: `function module:updateWho\(\)`
- **WoW API**: `GetWhoInfo(i)` - processes /who results
- **Event Trigger**: WHO_LIST_UPDATE
- **Test Method**: Run /who, verify unknown player levels cached

### 7. **updateBG()** - Battleground Detection

- **File**: `Prat-3.0/modules/PlayerNames.lua`
- **Line**: ~1480
- **Regex Search**: `function module:updateBG\(\)`
- **WoW API**: `GetBattlefieldScore(i)`
- **Event Trigger**: UPDATE_BATTLEFIELD_SCORE
- **Test Method**: Enter battleground, verify enemy levels cached

---

## CORE HELPER FUNCTIONS

### **addName()** - Level Storage Function

- **File**: `Prat-3.0/modules/PlayerNames.lua`
- **Line**: ~1540
- **Regex Search**: `function module:addName\(Name, Server, Class, Level, SubGroup, Source\)`
- **Purpose**: Caches level data in memory and persistent storage
- **Storage**: `self.Levels[Name:lower()] = Level`

### **getLevel()** - Level Retrieval Function

- **File**: `Prat-3.0/modules/PlayerNames.lua`
- **Line**: ~1600
- **Regex Search**: `function module:getLevel\(player\)`
- **Purpose**: Retrieves cached level data
- **Logic**: Checks memory cache, then persistent cache

### **FormatPlayer()** - Chat Display Function

- **File**: `Prat-3.0/modules/PlayerNames.lua`
- **Line**: ~1630
- **Regex Search**: `function module:FormatPlayer\(message, Name, frame, class\)`
- **Purpose**: Adds level to chat display
- **Key Code**: `message.PLAYERLEVEL = CLR:Level(tostring(level), level, Name, class)`

---

## IMPLEMENTATION ORDER (Easiest → Hardest)

1. ✅ **updateTarget()** - Immediate feedback, easy testing
2. ✅ **updateMouseOver()** - Similar to target
3. ✅ **updateParty()** - Small group testing
4. ✅ **updateGuild()** - Bulk data testing
5. ✅ **updateRaid()** - Large group testing
6. ✅ **updateWho()** - Unknown player detection
7. ✅ **WHO Event System** - Automatic WHO triggering

---

## QUICK NAVIGATION COMMANDS

```bash
# Search for any function by name
grep -n "function module:updateTarget" Prat-3.0/modules/PlayerNames.lua
grep -n "function module:addName" Prat-3.0/modules/PlayerNames.lua
grep -n "function module:getLevel" Prat-3.0/modules/PlayerNames.lua

# Search for level storage/retrieval
grep -n "self.Levels\[" Prat-3.0/modules/PlayerNames.lua
grep -n "PLAYERLEVEL" Prat-3.0/modules/PlayerNames.lua

# Search for WHO system
grep -n "updateWho\|WHO_LIST_UPDATE\|GetWhoInfo" Prat-3.0/modules/PlayerNames.lua
```

---

## TESTING CHECKLIST

- [ ] Target players → See levels in chat
- [ ] Hover over players → See levels in chat
- [ ] Join party → See party levels in chat
- [ ] Check guild roster → See guild levels in chat
- [ ] Join raid → See raid levels in chat
- [ ] Run /who → See unknown levels in chat
- [ ] Auto WHO triggers → See automatic detection

**Goal**: Chat messages show `[Level] PlayerName` for all detected players.
