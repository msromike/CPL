# CPL + Chattynator Integration Proposal

**To:** Chattynator Author
**From:** msromike (CPL Author)
**Date:** November 7, 2025
**Subject:** CPL Integration - Player Levels in Chattynator

---

## Overview

Hi! I've created **CPL (Chat Player Levels)**, a lightweight addon that displays player levels in chat messages. I've implemented optional integration with Chattynator that I'd like to share with you.

## What CPL Does

CPL automatically detects and displays player levels in chat using:

- Intelligent 8-hour caching (based on Prat-3.0's architecture)
- Smart WHO query system with throttling
- Guild roster scanning
- Target/mouseover detection

Example: `[60] PlayerName: Hello!`

## Chattynator Integration

**File:** `ChattynatorIntegration.lua` (135 lines)

The integration uses Chattynator's modifier API to prepend levels to player names in social channels (General, Trade, LFG, etc.). It's completely optional - CPL works standalone and gracefully detects if Chattynator is present.

### Key Features

1. **Zero Impact** - Only runs if Chattynator is installed
2. **Uses Chattynator API** - `Chattynator.API.AddModifier()`
3. **Social Channels Only** - Targets General, Trade, LFG, etc.
4. **Smart Detection** - Auto-discovers channels on load and zone change

### Integration Code Structure

```lua
-- Detects Chattynator presence
if not (CPL and Chattynator and Chattynator.API) then
    return
end

-- Adds level prefix modifier
Chattynator.API.AddModifier(function(message, name, ...)
    local level = CPL:getCachedLevel(name)
    if level then
        name = string.format("[%d] %s", level, name)
    end
    return message, name, ...
end)
```

## Benefits for Chattynator Users

1. **Enhanced Social Features** - See levels in busy trade/general channels
2. **No Configuration** - Works automatically when both addons installed
3. **Lightweight** - CPL's caching minimizes API calls
4. **Optional Dependency** - Users choose whether to install CPL

## Mutual Benefits

- **For Chattynator:** Enhanced functionality without maintenance burden
- **For CPL:** Exposure to Chattynator's user base
- **For Users:** Seamless integration between two complementary addons

## What I'm Proposing

1. **Optional Dependency Listing**
   - List CPL as an optional/recommended addon on Chattynator's CurseForge page
   - This drives download traffic to CPL while enhancing Chattynator's feature set
   - Users who want level display install CPL separately (you get enhanced features, I get downloads)

2. **Cross-Promotion Benefits**
   - I prominently feature Chattynator integration in CPL's README/CurseForge description
   - You optionally mention CPL as a recommended companion addon
   - Win-win: Your users get levels, my addon gets visibility

3. **No Code Merge Needed**
   - Integration stays entirely in CPL codebase
   - No maintenance burden on Chattynator
   - Users opt-in by installing both addons
   - Each addon remains independently maintained

## Repository & Code

- **GitHub:** <https://github.com/msromike/CPL>
- **Integration File:** `ChattynatorIntegration.lua`
- **License:** GPL v3.0
- **CurseForge:** (Publishing soon)

## Testing

The integration has been tested with:

- Chattynator installed/uninstalled scenarios
- Channel discovery across different zones
- Guild, party, raid, and social channels
- /reload and fresh login scenarios

## Closing

Thanks for creating Chattynator - it's an excellent chat addon! I've tried to implement the integration in a way that's respectful of your API and beneficial to mutual users.

Feel free to reach out if you have any questions, suggestions, or concerns.

**Contact:**

- GitHub: [@msromike](https://github.com/msromike)
- Discord: (if applicable - add your info)

---

**P.S.** I'm happy to provide any additional technical details or make adjustments based on your feedback!
