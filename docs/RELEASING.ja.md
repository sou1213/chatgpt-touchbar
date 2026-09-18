# ChatGPT Touch Barのリリース手順

**日本語** | [English](RELEASING.md)

公式バイナリはGitHub Actionsでビルドし、Developer ID Application証明書による署名、Apple公証、チケットのstaple、チェックサム生成、GitHubのビルド来歴証明まで行います。ローカルのアドホック署名ビルドを公式Releaseへアップロードしないでください。

## 初回設定

1. Apple Developer Programへ登録し、**Developer ID Application**証明書を作成します。
2. 「キーチェーンアクセス」から証明書と秘密鍵を、パスワード付き`.p12`として書き出します。
3. Appleの公証サービスへ送信できるApp Store Connect APIキーを作成し、`.p8`ファイル、キーID、Issuer IDを保存します。
4. GitHubリポジトリに`release`というActions Environmentを作ります。バージョンタグだけを許可し、必要に応じて承認者を設定します。
5. Environmentへ次のSecretsを登録します。

| Secret | 内容 |
| --- | --- |
| `MACOS_CERTIFICATE_P12_BASE64` | `.p12`をBase64化した内容 |
| `MACOS_CERTIFICATE_PASSWORD` | `.p12`を書き出したときのパスワード |
| `APP_STORE_CONNECT_API_KEY_P8_BASE64` | `.p8`をBase64化した内容 |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect APIキーのKey ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store ConnectのIssuer ID |

macOSでは、次のコマンドで認証ファイルを内容を変えずにBase64化できます。

```bash
/usr/bin/base64 -i DeveloperIDApplication.p12 | pbcopy
/usr/bin/base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

クリップボードの内容を対応するGitHub Secretへ貼り付けます。証明書、秘密鍵、パスワード、復号済み認証情報は決してコミットしないでください。

リポジトリのRelease設定で**Release immutability**を有効にします。ワークフローはReleaseを下書きで作成し、すべての配布物を添付してから公開するため、Immutable Releasesと両立します。

Apple公式資料：[Developer ID](https://developer.apple.com/developer-id/)、[macOSソフトウェアの公証](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、[公証ワークフローのカスタマイズ](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)。

## バージョンを公開する

1. `AppBundle/Info.plist`の`CFBundleShortVersionString`と`CFBundleVersion`を更新します。
2. ローカルで`swift test`と`./scripts/build_app.sh`を実行します。
3. リリース変更をコミットして`main`へプッシュします。
4. plistのバージョンと一致するセマンティックバージョンの注釈付きタグを作り、プッシュします。

```bash
git tag -a v0.3.0 -m "ChatGPT Touch Bar v0.3.0"
git push origin main
git push origin v0.3.0
```

Releaseワークフローは次の処理を行います。

1. タグを検証し、テストを実行する
2. 一時キーチェーンへ署名証明書を読み込む
3. Intel・Apple Silicon対応のUniversal Binaryを生成し、Hardened Runtimeと安全なタイムスタンプ付きでアプリを署名する
4. アプリをAppleへ公証に提出し、公証チケットをstapleする
5. DMGを生成・署名・公証し、公証チケットをstapleする
6. ZIPとSHA-256チェックサムを生成する
7. GitHubのビルド来歴証明を生成する
8. 下書きReleaseへすべての配布物を追加し、全工程に成功した場合だけ公開する
9. 一時キーチェーンと認証ファイルを削除する

告知する前に、Actionsに保存された公証ログを確認してください。GitHubからDMGをダウンロードし、クリーンなMacユーザー環境でインストール、初回起動、Safari権限、Touch Bar表示を確認します。

利用者は次のコマンドでビルド来歴を検証できます。

```bash
gh attestation verify ChatGPTTouchBar-v0.3.0-macOS.dmg \
  --repo sou1213/chatgpt-touchbar
```

GitHub公式資料：[Artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)、[Immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases)。

## ローカルでのパッケージ作成

Release用の認証情報がない状態で`./scripts/package_release.sh 0.3.0`を実行すると、アドホック署名のDMGとZIPを作成します。これはレイアウトとインストール手順の確認専用です。公開用ワークフローはDeveloper ID署名とApple公証がない状態では配布物を公開しません。
