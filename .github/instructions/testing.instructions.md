---
applyTo: "test_*.txt,*_test.lua,**/*test*.md"
description: "Testing guidelines for in-game verification"
---

# In-Game Testing Guidelines

## Test Command Format
- Use `/run` for quick tests
- Use `/script` for multiline (but prefer `/run` for portability)
- Print debug info: `/run print("Value:", variable)`
- Reload UI: `/reload` or `/console reloadui`

## Event Testing Pattern
```lua
/run local frame = CreateFrame("Frame"); frame:RegisterEvent("EVENT_NAME"); frame:SetScript("OnEvent", function(self, event, ...) print(event, ...); end)
```

## Chat Filter Testing Pattern
```lua
/run local function test(self, event, msg, author, ...)
  print("FILTER:", event, msg, author)
  return false, "[TEST] " .. msg, author, ...
end
ChatFrame_AddMessageEventFilter('CHAT_MSG_SAY', test)
/say Test message
```

## Database Inspection
- `/run DevTools_Dump(CPLDB)` (if DevTools installed)
- `/run for k,v in pairs(CPLDB.players) do print(k, v.Level, v.Class) end`

## Always Provide
1. Setup command (register filter, create frame, etc.)
2. Test command (generate event or trigger condition)
3. Expected output (what should print or appear in chat)
4. Cleanup command (remove filter, unregister events) if needed

## API Existence Checks
- `/run print("APIName:", type(APIName))` - shows "function", "table", or "nil"
- Test before assuming an API doesn't exist in Classic Era
