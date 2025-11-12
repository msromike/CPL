---
description: "Check if proposed code uses Classic Era-compatible APIs"
---

# Review WoW API Compatibility

Review the selected code or current file and check for:

1. **API Existence in Classic Era:** Verify every WoW API call
   - Use Wowpedia Classic Era docs: https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
   - Modern Classic shares Retail client - many "Retail-only" APIs may work
   - **Provide test commands** to verify API existence: `/run print("APIName:", type(APIName))`

2. **Hyperlink Handling:** Check if code modifies player names or hyperlinks
   - Look for ChatFrame_AddMessageEventFilter modifications
   - Check author parameter handling
   - Suggest testing approach if behavior is uncertain

3. **Lua Patterns:** Verify pattern escaping uses `%`, not `\`
   - Check string.gsub, string.find, string.match patterns
   - Verify magic characters are properly escaped

4. **Global Pollution:** Check all functions/vars are properly namespaced with CPL prefix
   - Functions: CPL_FunctionName or CPL.FunctionName
   - Variables: CPLDB, CPL_VERSION, etc.

5. **Event Registration:** Verify events are valid for Classic Era
   - Provide test command to verify event fires

Provide a checklist of issues found with line numbers and suggested fixes.
Include in-game test commands to verify fixes work.
