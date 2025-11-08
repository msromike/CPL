# CPL - Chat Player Levels

See player levels in chat - no more guessing who can help with that dungeon run or which lowbie needs assistance.

## What It Does

Automatically displays player levels before their name in all major chat channels. Simple, lightweight, and just works.

- Guild, officer, party, raid, whispers, say, yell - all covered
- Smart caching remembers levels (no spam queries)
- Works with target/mouseover detection
- Automatically integrates with Chattynator if it is installed
- New players show `[??]` until their level is detected

## Example

```
[60] Ragnaros: LF2M tank and healer for Strat
[??] Newplayer: Anyone up for SM?
```

Levels are detected automatically through chat activity, targeting, guild roster, and party membership. The addon remembers levels as you play - no need to look them up again.

## Features

- Zero configuration required - install and go
- Works with Blizzard's default chat and Chattynator chat addon
- Automatic level detection from chat, guild roster, and targeting
- Periodically updates levels to level-ups detect and rerolls
- Optional debug tools for troubleshooting

## Slash Commands

```
/cpl help - Show all commands
/cpl cache - View cached levels
/cpl channels - Show monitored channels
```

## Chattynator Integration

Install both CPL and Chattynator for the ultimate chat experience - levels appear seamlessly in Chattynator's custom chat windows.

## Credits

Inspired by Prat-3.0's level caching system. Open source under GPL v3.0 license.

[GitHub Repository](https://github.com/msromike/CPL)
