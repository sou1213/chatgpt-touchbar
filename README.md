# ChatGPT Touch Bar

![ChatGPT Touch Bar hero](docs/images/figma-readme-hero.png)

An unofficial macOS helper that shows your Codex five-hour and weekly usage limits on a MacBook Pro Touch Bar while ChatGPT/Codex—or a ChatGPT tab in Safari—is frontmost.

[日本語](#日本語) · [Install](#installation) · [How it works](#how-it-works) · [Privacy](#privacy) · [Figma design](https://www.figma.com/design/GShJz9Hb4yaNBMlk3zwZNu/ChatGPT-Touch-Bar-OSS-Design?node-id=3-8)

> [!NOTE]
> This displays the Codex/Work rate-limit windows exposed by Codex App Server. It does not report every ChatGPT model or feature limit.

## Screenshot

Safari with `chatgpt.com` frontmost:

![ChatGPT usage shown on a MacBook Pro Touch Bar](docs/images/safari-touch-bar.png)

## Features

- Shows remaining capacity for the five-hour and weekly Codex windows.
- Shows the next reset time.
- Refreshes every 30 seconds and immediately after switching to ChatGPT.
- Works with the ChatGPT/Codex desktop app and the active Safari tab on `chatgpt.com` or `chat.openai.com`.
- Replaces Safari's contextual controls only while a supported ChatGPT page is frontmost.
- Restores the standard Touch Bar when another app or website becomes active.
- Uses your existing Codex authentication—no API key or paid developer API usage is required.

## Requirements

- A MacBook Pro with a Touch Bar.
- macOS 12 Monterey or later.
- Swift 5.9 or later and Xcode Command Line Tools.
- ChatGPT, Codex, or the Codex CLI installed and signed in.
- Safari for web-page detection. Other browsers are not supported yet.

## Installation

There is no signed binary release yet. Build the app locally:

```bash
git clone https://github.com/sou1213/chatgpt-touchbar.git
cd chatgpt-touchbar
swift test
./scripts/build_app.sh
open dist/ChatGPTTouchBar.app
```

The generated app is ad-hoc signed and stays out of the Dock. To launch it automatically, add `dist/ChatGPTTouchBar.app` in **System Settings → General → Login Items**.

To stop it:

```bash
pkill -x ChatGPTTouchBar
```

## First Safari launch

The first time Safari detection runs, macOS asks whether ChatGPT Touch Bar may control Safari. Allow it so the helper can read the active tab URL.

If the prompt was denied, enable it later in **System Settings → Privacy & Security → Automation**.

The helper reads only the active Safari tab URL. It does not read page content, screenshots, cookies, messages, or form data.

## Usage

1. Launch `ChatGPTTouchBar.app`.
2. Bring the ChatGPT/Codex desktop app to the front, or open `chatgpt.com` in the active Safari tab.
3. The Touch Bar changes to the usage view. Switching away restores the standard Touch Bar.

To verify the data source without showing the UI:

```bash
swift run ChatGPTTouchBar --once-json
```

## How it works

The helper starts the local `codex app-server` process and calls the documented `account/rateLimits/read` method. It converts the returned usage percentages into remaining capacity, then renders two compact meters in an `NSTouchBar` view.

Foreground detection uses `NSWorkspace`. Safari support uses AppleScript to read only the current tab URL and matches it against an allowlist.

The App Server protocol is documented in the [official Codex App Server documentation](https://learn.chatgpt.com/docs/app-server#6-rate-limits-chatgpt).

## Configuration

Set these environment variables before launching the app:

| Variable | Purpose |
| --- | --- |
| `CHATGPT_TOUCHBAR_CODEX_BINARY` | Absolute path to the `codex` executable. |
| `CHATGPT_TOUCHBAR_TARGET_APPS` | Comma-separated app names or bundle identifiers. |
| `CHATGPT_TOUCHBAR_TARGET_WEB_HOSTS` | Comma-separated Safari hostnames. |

Example:

```bash
CHATGPT_TOUCHBAR_TARGET_WEB_HOSTS="chatgpt.com,chat.openai.com" \
  open dist/ChatGPTTouchBar.app
```

## Development

```bash
swift test
swift run ChatGPTTouchBar --once-json
./scripts/build_app.sh
```

The Figma-designed README artwork is also available as editable source at [`design/readme-hero.svg`](design/readme-hero.svg). Earlier layout explorations live in [`design/`](design/).

Contributions are welcome—see [CONTRIBUTING.md](CONTRIBUTING.md).

## Privacy

- Usage data is requested from a local Codex process authenticated with your existing account.
- No analytics, telemetry, remote database, or third-party server is included.
- Safari integration reads only the active tab URL.
- No API key is requested or stored.

## Limitations

- The system-modal Touch Bar presentation relies on private macOS selectors. It is unsuitable for Mac App Store distribution and may stop working after a macOS update.
- Safari is the only supported web browser in this release.
- The project has been developed for Touch Bar hardware and cannot be meaningfully tested on Macs without one.
- This project is unofficial and is not affiliated with or endorsed by OpenAI. ChatGPT and Codex are trademarks of their respective owner.

## 日本語

ChatGPT/Codexアプリ、またはSafariのChatGPTタブが最前面の間だけ、Codexの5時間枠・週次枠・リセット時刻をTouch Barへ表示するmacOS常駐ヘルパーです。

```bash
git clone https://github.com/sou1213/chatgpt-touchbar.git
cd chatgpt-touchbar
swift test
./scripts/build_app.sh
open dist/ChatGPTTouchBar.app
```

Safariを初めて検出するときは、macOSのAutomation権限を許可してください。確認するのは現在のタブURLだけで、画面・ページ本文・Cookie・会話内容は取得しません。

表示されるのはCodex/Workの共有利用枠です。通常のChatGPTチャットモデルすべての利用上限を取得するものではありません。

## License

Released under the [MIT License](LICENSE).

The system-modal Touch Bar approach was informed by Daytimeflow's `codex-touchbar-usage`. Its MIT notice is preserved in [`LICENSES/Daytimeflow-codex-touchbar-usage.txt`](LICENSES/Daytimeflow-codex-touchbar-usage.txt).
