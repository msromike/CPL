# CPL - Chat Player Levels

See player levels in chat - no more guessing who can help with that dungeon run or which lowbie needs assistance. Learns as it goes, the longer you use it the better it gets at displaying player levels.

## What It Does

Automatically displays player levels before their name (Chattynator) or after their name (Blizz UI) in chat output. Simple, lightweight, and just works.

- Guild, officer, party, raid, whispers, say, yell - all covered
- Smart caching remembers levels and detects level-ups and rerolls
- Automatically integrates with Chattynator if it is installed
- Unknown players show no level prefix until detected

## Example

```
[60] Ragnaros: LF2M tank and healer for Strat
Newplayer: Anyone up for SM?
```

Levels are detected automatically through normal user in-game activity. The addon finds and remembers player levels as you play.

## Features

- Zero configuration required - install and go
- Works with Blizzard's default chat and Chattynator chat addon
- Periodically updates levels to detect level-ups and rerolls
- Automatic level detection from chat, guild roster, targeting, and party/raid membership

## Slash Commands

```
/cpl help     - Show all commands
/cpl status   - Show addon status with optional filters
              -what: Stats (player count, avg level, timestamps)
              -who:  Class breakdown
              -how:  Collection method breakdown
              <name>: Filter by player name
/cpl channels - Show monitored channels
```

## Chattynator Integration

Install both CPL and Chattynator for the ultimate chat experience - levels appear seamlessly in Chattynator's custom chat windows.

## Credits

Inspired by Prat-3.0's level caching system. Open source under GPL v3.0 license.

[GitHub Repository](https://github.com/msromike/CPL)
