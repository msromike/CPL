# CPL + Chattynator Integration

**From:** msromike
**Date:** November 7, 2025
**Re:** Chattynator integration implementation

---

## Summary

Built CPL (Chat Player Levels) - displays player levels in chat. Implemented optional integration with Chattynator using your modifier API. Integration code is entirely in CPL, requires no changes to Chattynator.

## Technical Implementation

**Architecture:**
- Uses `Chattynator.API.AddModifier()` to inject level prefixes
- 135-line integration module (`ChattynatorIntegration.lua`)
- Graceful degradation if Chattynator not present
- Level caching system (8hr expiry) based on Prat-3.0 approach

**Code:**
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

**Scope:**
- Social channels only (General, Trade, LFG, etc.)
- Auto-discovers channels on load/zone change
- Zero performance impact when Chattynator not installed

## Testing

Verified with:
- Chattynator installed/uninstalled scenarios
- Channel discovery across zones
- Guild, party, raid, and social channels
- /reload and fresh login scenarios

## Potential Collaboration

If you're interested, listing CPL as an optional/recommended addon on your CurseForge page would:
- Provide level display feature to your users
- Drive installs to CPL
- Require zero maintenance on your end

No pressure - integration works either way. Users can install both if they want the feature.

## Repository

- **GitHub:** https://github.com/msromike/CPL
- **Integration:** `ChattynatorIntegration.lua`
- **License:** GPL v3.0
- **Status:** Production ready, CurseForge submission pending

---

Available for technical discussion if needed.

Contact: GitHub [@msromike](https://github.com/msromike)
