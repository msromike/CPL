# HANDOFF: Event-Driven Duplicate Suppression

## Context
Chat channels (especially automated ones like death alerts) send multiple rapid messages from same player.
Currently causes duplicate queue additions and debug spam.

## The Problem
```
[CHAT] - Channel 1 (ushccomms) [Youkickmydog]
[CHAT] - Channel 1 (ushccomms) [Youkickmydog]  ← Duplicate processing
[CHAT] - Channel 1 (ushccomms) [Youkickmydog]  ← Same player
... (7 messages total from automated death alert)
```

Each message triggers full queue logic even though it's the same player.

## The Solution: Pure Event-Driven State Machine

**NO TIMERS. NO TIME WINDOWS. Pure state tracking.**

```lua
-- State variable (add at top of CPL.lua after other state vars)
local lastProcessedPlayer = nil

-- In OnChannelChat function (BEFORE any processing logic)
local playerName = strsplit("-", author, 2)
local key = playerName:lower()

-- Event-driven drop logic
if key == lastProcessedPlayer then
    return false  -- Same player as last message, DROP
end

-- New player detected, process it
lastProcessedPlayer = key

-- ... continue with existing queue/debug logic ...
```

## The Logic Flow

```
Event: Message from Youkickmydog
  lastProcessedPlayer = nil
  → NEW PLAYER → PROCESS → Queue + Log
  lastProcessedPlayer = "youkickmydog"

Event: Message from Youkickmydog
  lastProcessedPlayer = "youkickmydog"
  → SAME PLAYER → DROP

Event: Message from Youkickmydog
  → SAME PLAYER → DROP

Event: Message from Maulley
  lastProcessedPlayer = "youkickmydog"
  → NEW PLAYER → PROCESS → Queue + Log
  lastProcessedPlayer = "maulley"
```

## Result
- ✅ Captures every unique player
- ✅ Suppresses rapid duplicates from same player
- ✅ Reduces debug spam by ~80%
- ✅ Only queues WHO once per player per batch
- ✅ No timers, pure event-driven
- ✅ Clean, readable debug output

## Where to Apply

**Primary:** `OnChannelChat` filter in `CPL.lua` (lines ~310-360)

**Potential Future:** Could apply same pattern to:
- `updateMouseOver()` - If mousing over same unit repeatedly
- `updateTarget()` - If targeting same unit repeatedly

But chat is the main offender due to automated message batches.

## Code Location
File: `CPL.lua`
Function: `OnChannelChat` (Chat message processing function)
Section: Chat Channel Monitoring (~line 310)

## Implementation Priority
**Medium** - Not critical, but significantly improves debug clarity and reduces redundant queue operations.
