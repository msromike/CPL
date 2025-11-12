---
applyTo: "**/*.lua"
description: "Lua-specific coding rules for WoW addons"
---

# Lua Pattern Matching Rules

## Lua Patterns vs Regex
- Lua uses `%` for escaping, not `\`
- Character classes: `%a` (letters), `%d` (digits), `%s` (space), `%w` (alphanumeric)
- Magic characters: `( ) . % + - * ? [ ] ^ $`
- Repetition: `*` (0+), `+` (1+), `-` (lazy 0+), `?` (0-1)

## WoW Hyperlink Format
- Player link: `|Hplayer:Name:LineID|h[DisplayName]|h`
- With color: `|Hplayer:Name:LineID|h|cffCOLORName|r|h`
- Item link: `|Hitem:ItemID:...|h[ItemName]|h`

## String Manipulation Best Practices
- Use `string.format()` for readability
- Cache `string.gsub` results if used repeatedly
- Use `string.find()` before `string.gsub()` if pattern might not match
- Remember gsub returns (newString, numReplacements)

## Performance Tips
- Minimize table creation in hot paths (event handlers)
- Cache WoW API calls that don't change (UnitName, GetRealmName)
- Use local functions for frequently called code
