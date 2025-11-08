# Chattynator Integration Handoff

## Goal
Prepend player levels (e.g., `[60]`) to player names in Chattynator chat addon.

## Current Status
**Discovery phase complete. Ready to implement filtering.**

## What We Know (CONFIRMED)

### 1. Chattynator Modifier System Works
- `Chattynator.API.AddModifier(function)` successfully registers our function
- Modifier is called for EVERY chat message
- We can modify `data.text` with string.gsub - this works

### 2. Data Structure
Messages passed to modifier contain:
```lua
data = {
    text = "actual message text with hyperlinks",
    typeInfo = {
        event = "CHAT_MSG_CHANNEL" | "CHAT_MSG_YELL" | etc,
        type = "NONE" | "YELL" | "EMOTE" | etc,
        player = {
            name = "PlayerName-Realm",
            class = "WARRIOR",
            race = "Orc",
            sex = 2
        },
        channel = {  -- only for CHAT_MSG_CHANNEL events
            name = "Trade" | "General" | etc,
            index = 3,
            zoneID = 2,
            isDefault = true
        }
    }
}
```

### 3. Text Format (CRITICAL DISCOVERY)
The `data.text` contains **RAW HYPERLINK CODES**, not plain text:

**Example:**
```
|Hplayer:Xirohero-Doomhowl:1035:YELL:|h|cffc79c6eXirohero|r|h yells: message
```

**Format breakdown:**
- `|Hplayer:Name-Realm:ID:CHANNEL:|h` - Hyperlink opening
- `|cffCOLOR` - Color code
- `PlayerName` - Actual name
- `|r` - Color reset
- `|h` - Hyperlink closing

**To prepend level:** Insert `[60] ` right after `|h` and before color code:
```
|Hplayer:Xirohero-Doomhowl:1035:YELL:|h[60] |cffc79c6eXirohero|r|h yells: message
```

### 4. The Channel Problem
`event = "CHAT_MSG_CHANNEL"` includes:
- **Visible channels we WANT:** Trade, General, LocalDefense, LookingForGroup, WorldDefense
- **Hidden addon spam channels we DON'T WANT:** Various addon communication channels

Chattynator **ignores/hides** the addon spam channels, so when we modify those, we don't see any effect.

**We were modifying hidden channels and wondering why nothing changed.**

## What We Need to Do

### Step 1: Enumerate ALL Channel Names
Log every unique `channel.name` value to see what exists:

```lua
-- Current code in ChattynatorIntegration.lua logs:
-- event, type, player.name, channel.name, text (first 60 chars)
```

User needs to:
1. `/reload` with current code
2. Let it run for a few minutes of chat activity
3. Copy debug frame output
4. Identify which channel names are the visible ones we care about

### Step 2: Filter to ONE Channel (General Chat)
Once we know the exact `channel.name` for General chat:

```lua
if event == "CHAT_MSG_CHANNEL" then
    local channelName = data.typeInfo.channel and data.typeInfo.channel.name
    if channelName ~= "General" then  -- or whatever the exact name is
        return  -- Skip all other channels
    end
end
```

### Step 3: Test Level Prepending on General ONLY
With filtering in place, implement the level prepending:

```lua
local level = CPL:getLevel(nameOnly)
if level then
    local levelPrefix = string.format("[%02d] ", level)
    local pattern = "(|Hplayer:[^|]+|h)"
    data.text = data.text:gsub(pattern, function(hyperlink)
        return hyperlink .. levelPrefix
    end, 1)
end
```

### Step 4: Verify in General Chat
User talks to someone in General chat and confirms level appears.

### Step 5: Expand to Other Channels
Once General works, add other visible channels:

```lua
local validChannels = {
    General = true,
    Trade = true,
    LocalDefense = true,
    LookingForGroup = true,
    WorldDefense = true,
}
if not validChannels[channelName] then
    return
end
```

### Step 6: Add Other Event Types
Add non-channel events:
- CHAT_MSG_YELL
- CHAT_MSG_SAY
- CHAT_MSG_GUILD
- CHAT_MSG_PARTY
- CHAT_MSG_RAID
- CHAT_MSG_WHISPER
- CHAT_MSG_TEXT_EMOTE

## Key Files
- `ChattynatorIntegration.lua` - Main integration code
- `CPL.lua` - Contains `CPL:getLevel(name)` function
- `Debug.lua` - Debug frame (copy button has height limit - resize frame bigger to copy lots of output)

## Current Code State
`ChattynatorIntegration.lua` is currently dumping all messages with event/type/player/channel/text for enumeration.

## Next Immediate Action
Wait for user to provide list of channel names from debug output, then implement Step 2 (filter to General only).
