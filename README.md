# CPL - Chat Player Levels

A lightweight World of Warcraft Classic addon that displays player levels next to names in chat channels.

## Features

- **Automatic Level Detection** - Shows player levels in chat messages across all major channels
- **Intelligent Caching** - Remembers player levels (with expiry) to minimize API calls
- **Multiple Collection Methods:**
  - **Guild Roster** - Instantly detects all guild member levels (including offline)
  - **Party Detection** - Automatically captures party member levels
  - **Raid Detection** - Automatically captures raid member levels (including offline)
  - **Target/Mouseover** - Captures levels when you target or mouseover players
  - **Smart WHO Queries** - Automatically looks up unknown players with intelligent throttling
- **Chattynator Integration** - Optional enhanced integration with Chattynator chat addon
- **Debug Module** - Optional debug tools for developers (comment out Debug.lua in .toc to disable)

## Installation

### Manual Installation

1. Download the latest release
2. Extract the `CPL` folder to `World of Warcraft\_classic_era_\Interface\AddOns\`
3. Restart WoW or reload UI (`/reload`)

### CurseForge

Coming soon!

## Usage

CPL works automatically once installed. Player levels appear in brackets next to names:

```
[60] PlayerName: Hello!
```

### Slash Commands

| Command | Description |
|---------|-------------|
| `/cpl help` | Show all available commands |
| `/cpl cache` | Display cached player levels |
| `/cpl cache <name>` | Look up a specific player in cache |
| `/cpl channels` | Show monitored chat channels |

### Debug Commands (requires Debug.lua)

| Command | Description |
|---------|-------------|
| `/cpl debug` | Toggle debug output on/off |
| `/cpl queue` | Show WHO query queue status |
| `/cpl debugframe` | Show/hide debug frame window |

## Chattynator Integration

CPL works with both the default Blizzard chat UI and:
    [Chattynator](https://www.curseforge.com/wow/addons/chattynator):

- **Blizzard UI:** CPL works out-of-the-box with the default WoW chat interface
- **Chattynator:** Automatic integration with Chattynator

## Monitored Chat Channels

By default, CPL monitors these channels:

- Guild (`GUILD`)
- Party (`PARTY`, `PARTY_LEADER`)
- Raid (`RAID`, `RAID_LEADER`, `RAID_WARNING`)
- Officer (`OFFICER`)
- Whispers (`WHISPER`, `WHISPER_INFORM`)
- Say/Yell (`SAY`, `YELL`)
- Custom channels 1-7 (`CHANNEL`)

## Technical Details

- **Cache Duration:** 8 hours per player
- **WHO Cooldown:** 5 seconds (WoW API throttle limit)
- **Guild Scan Cooldown:** 10 minutes
- **SavedVariables:** CPLDB (stores player level cache)

## Configuration

Edit `CPL.toc` to customize:

- **Disable Debug Module:** Comment out `Debug.lua` line
- **Change Monitored Channels:** Edit `CHAT_EVENTS_WITH_LEVELS` in `CPL.lua`

## Credits

- **Author:** msromike
- **Inspired by:** [Prat-3.0](https://github.com/Prat-3.0/Prat-3.0) level caching system
- **Special Thanks:** Prat-3.0 Development Team for the intelligent caching approach

## License

GNU General Public License v3.0

This project contains code derived from Prat-3.0, which is licensed under GPL v2.0 or later.

## Support

- **Issues:** [GitHub Issues](https://github.com/msromike/CPL/issues)
- **Source:** [GitHub Repository](https://github.com/msromike/CPL)

## Version

Current version: **1.0.5**

See [CHANGELOG.md](CHANGELOG.md) for version history.
