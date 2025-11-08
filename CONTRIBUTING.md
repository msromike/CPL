# Contributing to CPL

Thank you for your interest in contributing to CPL (Chat Player Levels)!

## How to Contribute

### Reporting Bugs

Found a bug? Please open an issue on GitHub with:

- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- WoW version and addon version
- Any error messages from `/console scriptErrors 1`

### Suggesting Features

Feature requests are welcome! Please include:

- Clear description of the feature
- Use case / why it would be helpful
- Any implementation ideas (optional)

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly in-game
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Setup

1. Clone the repository to your WoW AddOns folder
2. Enable debug mode by ensuring `Debug.lua` is loaded in `CPL.toc`
3. Use `/cpl debug` and `/cpl debugframe` for testing
4. Test with and without Chattynator installed

### Code Style

- Follow existing code formatting
- Use descriptive variable names
- Comment complex logic
- Maintain the modular architecture (CPL.lua, Debug.lua, ChattynatorIntegration.lua)

### Testing Checklist

Before submitting a PR, please test:

- [ ] Works with Debug.lua enabled
- [ ] Works with Debug.lua disabled (commented in .toc)
- [ ] Works with Chattynator installed
- [ ] Works without Chattynator
- [ ] No errors in default UI (`/console scriptErrors 1`)
- [ ] Cache persists through /reload
- [ ] WHO queries respect throttling

## Architecture Overview

- **CPL.lua** - Core addon logic (level detection, caching, WHO queries)
- **Debug.lua** - Optional debug module (can be disabled via .toc)
- **ChattynatorIntegration.lua** - Optional Chattynator integration

## License

By contributing, you agree that your contributions will be licensed under GPL v3.0.

## Questions?

Open an issue or discussion on GitHub!
