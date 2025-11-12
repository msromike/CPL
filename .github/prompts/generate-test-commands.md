---
description: "Generate in-game test commands for a feature"
---

# Generate In-Game Test Commands

For the selected code or feature, generate:

1. **Setup command:** `/run` snippet to initialize (register event, add filter, etc.)
   - Should be copy-pasteable directly into WoW chat
   - Include any necessary variable declarations
   - Print confirmation message

2. **Test command:** How to trigger the feature
   - Example: `/say Test`, whisper someone, target a player, join guild, etc.
   - Specify what action to perform
   - Multiple test scenarios if applicable

3. **Expected output:** What should appear in chat or be printed
   - Exact expected text or pattern
   - Where to look (chat window, console, etc.)

4. **Inspection command:** How to verify database changes
   - Example: `/run print(CPLDB.players["PlayerName"].Level)`
   - Dump relevant data structures
   - Check for expected values

5. **Cleanup command:** How to remove test hooks (if needed)
   - Remove filters
   - Unregister events
   - Reset test state

Format as copyable commands with explanations.
Separate each command clearly for easy copy-paste.
