# Contributing

Thanks for helping improve ChatGPT Touch Bar.

## Development setup

Requirements are macOS 12 or later, Swift 5.9 or later, and Xcode Command Line Tools.

```bash
swift test
swift run ChatGPTTouchBar --once-json
./scripts/build_app.sh
```

Hardware behavior must be verified on a MacBook Pro with a Touch Bar. Please also check that switching to another app or a non-ChatGPT Safari tab restores the standard Touch Bar.

## Pull requests

- Keep each change focused.
- Add or update tests for parsing and matching behavior.
- Do not commit account data, API keys, cookies, logs, or screenshots containing personal information.
- Explain any use of private macOS APIs and fail safely when a selector is unavailable.
- Run `swift test` before opening a pull request.

## Issues

When reporting a bug, include the macOS version, Mac model, installation method, affected frontmost app or URL host, and relevant logs with personal information removed.
