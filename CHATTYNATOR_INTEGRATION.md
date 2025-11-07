# Chattynator Integration Plan

## ISSUE RESOLVED: Debug Output Duplication

**Problem:** CPL's debug output was being displayed 10+ times per message in Chattynator, making the chat window unusable.

**Root Cause:** Chattynator hooks `DEFAULT_CHAT_FRAME:AddMessage()` to intercept all messages. When CPL uses `print()`, it triggers Chattynator's hook, which then displays the message in ALL of Chattynator's chat windows/tabs/frames, causing massive duplication.

**Solution:** Store a reference to the original `print()` function BEFORE Chattynator loads and hooks it.

### Implementation

1. **Capture original print function at addon load time** (before any hooks):

   ```lua
   -- Store original print function before Chattynator (or other addons) hook it
   -- This prevents debug spam from being duplicated across multiple Chattynator windows
   local originalPrint = print
   ```

2. **Use originalPrint in debug function** to bypass Chattynator's hook:

   ```lua
   function CPL:debug(...)
       if self.debugMode then
           local args = {...}
           local parts = {}
           for i = 1, select("#", ...) do
               parts[i] = tostring(args[i])
           end
           -- Use original print to avoid Chattynator duplication
           originalPrint("CPL DEBUG: " .. table.concat(parts, " "))
       end
   end
   ```

3. **Proper string concatenation** for all print calls (to ensure single-line messages):

   ```lua
   print("CPL Debug mode: " .. (self.debugMode and "ON" or "OFF"))
   ```

**Result:**

- ✅ Debug messages appear only ONCE in chat
- ✅ Debug messages still visible in both Chattynator AND standard chat frame
- ✅ No interference with Chattynator's message processing
- ✅ All messages properly formatted as single strings

---

## What We Learned

1. **Modifiers receive RAW text with hyperlinks intact**
   - Example: `G. |Hplayer:Name:123:GUILD|h[Name]|h: message`
   - NOT the final displayed text `G. Name: message`

2. **Player hyperlink pattern from ClassColors.lua:**

   ```lua
   local playerPattern = "(|Hplayer:[^|]+|h%[?)([^|%[%]][^c%[%]][^%[%]]-)(%]?|h)"
   ```

   - Captures: `(hyperlink_start)` `(player_name)` `(hyperlink_end)`
   - Replace middle part: `%1[10:PlayerName]%3`

3. **Our modifier was breaking because:**
   - We tried to match plain text `G. PlayerName:`
   - Should match hyperlink `|h[PlayerName]|h`
   - The `heights = nil` error was because we corrupted data.text

## Correct Implementation

```lua
function CPL:chattynatorModifier(data)
    -- Only process messages with player info
    if not data.typeInfo or not data.typeInfo.player or not data.typeInfo.player.name then
        return
    end

    local playerName = data.typeInfo.player.name
    local lookupName = playerName:match("([^%-]+)") or playerName
    local level = self:getLevel(lookupName)

    -- Format level
    local levelStr = level and string.format("%02d", level) or ".."

    -- Use Chattynator's playerPattern approach
    -- Match: |Hplayer:...|h[PlayerName]|h
    -- Replace [PlayerName] with [10:PlayerName]
    local playerPattern = "(|Hplayer:[^|]+|h)%[([^%]]+)%](|h)"
    data.text = data.text:gsub(playerPattern, function(prefix, name, suffix)
        -- Only modify if this is OUR player
        if name == lookupName or name == playerName then
            return prefix .. "[" .. levelStr .. ":" .. name .. "]" .. suffix
        end
        return prefix .. "[" .. name .. "]" .. suffix
    end)
end
```

## Next Steps

1. Implement proper hyperlink pattern matching
2. Test with verbose debug to see actual data.text format
3. Ensure we don't break Chattynator's height calculations
