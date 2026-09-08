# ChatGPT Touch Bar

![ChatGPT Touch Bar hero](docs/images/figma-readme-hero.png)

An unofficial macOS helper that shows your Codex five-hour and weekly usage limits on a MacBook Pro Touch Bar while ChatGPT/Codex—or a ChatGPT tab in Safari—is frontmost.

[日本語](#日本語) · [Install](#installation) · [How it works](#how-it-works) · [Privacy](#privacy) · [Figma design](https://www.figma.com/design/GShJz9Hb4yaNBMlk3zwZNu/ChatGPT-Touch-Bar-OSS-Design?node-id=3-8)

> [!NOTE]
> This displays the Codex/Work rate-limit windows exposed by Codex App Server. It does not report every ChatGPT model or feature limit.

## Screenshot

Safari with `chatgpt.com` frontmost (v0.2.0; the current version has a larger icon and clearer labels):

![ChatGPT usage shown on a MacBook Pro Touch Bar](docs/images/safari-touch-bar.png)

## Features

- Shows remaining capacity for the five-hour and weekly Codex windows.
- Shows the next reset time.
- Refreshes every 30 seconds and immediately after switching to ChatGPT.
- Works with the ChatGPT/Codex desktop app and the active Safari tab on `chatgpt.com` or `chat.openai.com`.
- Replaces Safari's contextual controls only while a supported ChatGPT page is frontmost.
- Restores the standard Touch Bar when another app or website becomes active.
- Uses your existing Codex authentication—no API key or paid developer API usage is required.
- Includes an optional Survival Mode with pixel hearts, drumsticks, and a pixel OpenAI logo.

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

For a permanent location, use Finder to copy `dist/ChatGPTTouchBar.app` into your Applications folder, then launch that copy and add it to Login Items. Keep only one copy running. On macOS Monterey, Login Items is under **System Preferences → Users & Groups**.

If `swift` is unavailable, install Apple's Command Line Tools with `xcode-select --install`. Check `swift --version`: this project requires Swift 5.9 or later, which may require a newer Xcode/macOS combination than the app's macOS 12 runtime minimum.

### Update or uninstall

To update a source installation, run `git pull --ff-only`, then `./scripts/build_app.sh`. Quit the running helper before replacing your installed app with the new build and reopening it.

To uninstall, quit the helper, remove it from Login Items if added, and move `ChatGPTTouchBar.app` to the Trash. Your ChatGPT/Codex account and authentication remain intact.

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

### Survival Mode

Tap the ChatGPT logo **five times within three seconds** to enter Survival Mode. Repeat to return to the standard meters; your choice is saved across restarts.

![Survival Mode Touch Bar design](design/survival-mode.svg)

- Ten hearts show five-hour remaining capacity; ten drumsticks show weekly remaining capacity.
- Each half icon represents 5%. Icons round down; the numeric percentage keeps the normal display precision.
- The full reset label is unchanged. Dim empty icons with `—` mean unavailable/loading, not zero remaining capacity.
- To fit the icons, this theme hides the `ChatGPT` wordmark but keeps its tappable logo.

Editable artwork is in [`design/pixel/`](design/pixel/): 16×16 meters and a 20×20 OpenAI pixel logo traced from the bundled template to preserve its interwoven bands. No Minecraft game textures are bundled. The OpenAI logo remains OpenAI's trademark.

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
  ./dist/ChatGPTTouchBar.app/Contents/MacOS/ChatGPTTouchBar
```

Quit an existing instance first. This example runs the executable directly so it inherits the shell environment; Finder launches do not use these shell settings. Changing target apps or hosts only changes when the bar appears; it does not add another AI provider or switch accounts.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| No Dock icon or app window | Expected: this is a background helper. Activate ChatGPT or a supported Safari tab. |
| Safari keeps showing its usual controls | Allow Safari under Automation permissions, and make sure the active tab is on a supported host. |
| `codex not found` | Install ChatGPT/Codex with its bundled CLI, or set `CHATGPT_TOUCHBAR_CODEX_BINARY` to your CLI path. |
| `usage unavailable` | Run `swift run ChatGPTTouchBar --once-json` and confirm that the local Codex account is signed in and can report usage. |
| Numbers differ from the browser account | The local Codex account supplies the numbers. Signing into another account in Safari does not change that data source. |

If you report an [issue](https://github.com/sou1213/chatgpt-touchbar/issues), include your Mac model, macOS version, and the error message. Remove account details and private information from logs before sharing them.

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

常用する場合は、Finderで `dist/ChatGPTTouchBar.app` を「アプリケーション」フォルダへコピーして起動してください。Dockアイコンや通常のウインドウは表示されません。自動起動は「システム設定 → 一般 → ログイン項目」から追加できます。

ロゴを3秒以内に5回タップすると「サバイバルモード」へ切り替わり、OpenAIロゴ、5時間のハート、週次の骨付き肉がドット絵になります。再度5回で通常表示に戻り、選択は再起動後も保存されます。半個が5%で、端数は切り捨てます。数値の％とリセット表示は維持します。このテーマではスペース確保のためロゴ横の「ChatGPT」文字のみ非表示にしています。

更新は `git pull --ff-only` と `./scripts/build_app.sh` を実行し、起動中のヘルパーを終了してからアプリを入れ替えます。終了にはアクティビティモニタ、または `pkill -x ChatGPTTouchBar` を使えます。削除するときはログイン項目から外し、アプリをゴミ箱へ移動してください。

ブラウザとローカルCodexで異なるアカウントを使っている場合、表示される残量はローカルCodex側のものです。取得できない場合は `swift run ChatGPTTouchBar --once-json` でエラーを確認してください。

表示されるのはCodex/Workの共有利用枠です。通常のChatGPTチャットモデルすべての利用上限を取得するものではありません。

## License

Released under the [MIT License](LICENSE).

The system-modal Touch Bar approach was informed by Daytimeflow's `codex-touchbar-usage`. Its MIT notice is preserved in [`LICENSES/Daytimeflow-codex-touchbar-usage.txt`](LICENSES/Daytimeflow-codex-touchbar-usage.txt).
