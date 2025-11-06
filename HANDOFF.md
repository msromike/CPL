# CPL Handoff Document - FIXED

## SOLUTION FOUND

**Problem**: Creating a separate frame and registering WHO_LIST_UPDATE *after* sending the query
**Solution**: Register WHO_LIST_UPDATE on the main event frame at load time (like Prat does)

### What Prat Does (found in PlayerNames.lua lines 1319-1458)

```lua
-- In OnModuleEnable():
self:RegisterEvent("WHO_LIST_UPDATE", "updateWho")

-- Handler function:
function module:updateWho()
  if self.wholib then return end

  local Name, Class, Level, Server, _
  for i = 1, GetNumWhoResults() do
    Name, _, Level, _, _, Class = GetWhoInfo(i)
    self:addName(Name, Server, Class, Level, nil, "WHO")
  end
end
```

**Key insight**: The event handler is ALWAYS registered, not created on-demand. This way when ANY WHO query completes (from any source), the event fires and gets handled.

## What Works

1. **Chat monitoring** - Detects player names in channels 1, 2, 5
2. **Queue system** - Adds unknown players to `CPL.WhoQueue`
3. **Hardware event hook** - `WorldFrame:OnMouseDown` triggers queue processing
4. **WHO queries sent** - `C_FriendList.SendWho()` fires successfully on click
5. **WHO results visible** - Game shows "PlayerName: Level XX..." in chat
6. **Basic caching** - Target/mouseover/party/raid players cached to `CPLDB.players[name] = {level, timestamp}`

## Current Problem

**WHO_LIST_UPDATE event never fires**, so `processWhoResults()` is never called.

### Evidence from logs

```
CPL DEBUG: HARDWARE EVENT: Sending WHO query for antfrost
>>> Created whoFrame <<<
>>> Registering WHO_LIST_UPDATE event <<<
Antfrost: Level 48 Troll Mage <Unboon> - Orgrimmar  // <-- Game shows result
1 |4player:players; total
// <-- No ">>> Event fired: WHO_LIST_UPDATE <<<" message
```

The WHO query works (results appear in chat), but our event handler never receives `WHO_LIST_UPDATE`.

## Code Structure

### Queue Flow

1. `OnChannelChat()` - Chat filter adds players to queue if not cached
2. Mouse click → `processQueue()` - Pops player, sends WHO query
3. **BROKEN**: `WHO_LIST_UPDATE` should fire → `processWhoResults()` should run
4. **BROKEN**: Should parse results and cache or re-queue on failure

### Current Handler Setup (lines 286-298 in CPL.lua)

```lua
if not self.whoFrame then
    self.whoFrame = CreateFrame("Frame")
    self.whoFrame:SetScript("OnEvent", function(frame, event)
        print(">>> Event fired:", event, "<<<")  // Never prints
        if event == "WHO_LIST_UPDATE" then
            CPL:processWhoResults()
            frame:UnregisterEvent("WHO_LIST_UPDATE")
        end
    end)
end
self.whoFrame:RegisterEvent("WHO_LIST_UPDATE")
C_FriendList.SendWho(nextPlayer)
```

## What Prat Author Said

- Prat DOES use WHO queries on hardware events
- It works in Prat
- The API exists and is not protected

## Next Steps to Investigate

1. **Check if event name is wrong** - Maybe it's not `WHO_LIST_UPDATE` in Classic Era?
2. **Try old API** - `SendWho()` instead of `C_FriendList.SendWho()`?
3. **Check Prat source** - Find actual WHO event handling code
4. **Test with /who command** - Does typing `/who playername` trigger our handler?
5. **Try different event** - `PLAYER_TARGET_CHANGED` fires, maybe WHO has different event?

## Data Structures

```lua
CPL.WhoQueue = {}  -- [playername:lower()] = true
CPL.whoTarget = nil  -- Currently queried player name
CPLDB.players = {}  -- [playername:lower()] = {level_number, epoch_timestamp}
```

## Testing Commands

- `/cpl debug` - Toggle debug output
- `/cpl queue` - Show WHO queue contents
- `/cpl cache` - Show cached players
- `/cpl who <name>` - Manual WHO test (requires social frame open - doesn't use queue)

## Files

- `CPL.lua` - Main addon code (307 lines)
- `CPL.toc` - Addon manifest
- `.luacheckrc` + `.vscode/settings.json` - Linter configs (WorldFrame whitelisted)

## Last Commit

`99216b4` - "Wire WHO queries to hardware event queue processing"

- WHO queries send successfully
- Event handler registered but never fires
- Need to debug why `WHO_LIST_UPDATE` doesn't trigger
