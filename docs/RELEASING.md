# Releasing ChatGPT Touch Bar

[日本語](RELEASING.ja.md) | **English**

Official binaries are built in GitHub Actions, signed with a Developer ID Application certificate, notarized by Apple, stapled, checksummed, and accompanied by GitHub build-provenance attestations. Do not upload a local ad-hoc build as an official Release.

## One-time setup

1. Join the Apple Developer Program and create a **Developer ID Application** certificate.
2. Export the certificate and private key from Keychain Access as a password-protected `.p12` file.
3. Create an App Store Connect API key that can submit software to Apple's notary service. Save its `.p8` file, key ID, and issuer ID.
4. In the repository, create a GitHub Actions environment named `release`. Restrict it to protected version tags and add a required reviewer when appropriate.
5. Add the following environment secrets:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE_P12_BASE64` | Base64-encoded `.p12` contents |
| `MACOS_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `APP_STORE_CONNECT_API_KEY_P8_BASE64` | Base64-encoded `.p8` contents |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer ID |

On macOS, encode the binary credential files without modifying them:

```bash
/usr/bin/base64 -i DeveloperIDApplication.p12 | pbcopy
/usr/bin/base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

Paste each clipboard value into the corresponding GitHub secret. Never commit certificates, private keys, passwords, or decoded credentials.

Enable **Release immutability** under the repository's release settings. The workflow creates a draft, uploads every asset, and only then publishes it, so it remains compatible with immutable releases.

Apple's references: [Developer ID](https://developer.apple.com/developer-id/), [notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), and [custom notarization workflows](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## Publish a version

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `AppBundle/Info.plist`.
2. Run `swift test` and `./scripts/build_app.sh` locally.
3. Commit and push the release changes to `main`.
4. Create an annotated semantic-version tag that exactly matches the plist version, then push it:

```bash
git tag -a v0.3.0 -m "ChatGPT Touch Bar v0.3.0"
git push origin main
git push origin v0.3.0
```

The Release workflow then:

1. validates the tag and runs the test suite;
2. imports the signing identity into an ephemeral keychain;
3. builds a Universal Binary for Intel and Apple Silicon, then signs the app with Hardened Runtime and a secure timestamp;
4. submits the app to Apple's notary service and staples its ticket;
5. creates and signs a DMG, notarizes it, and staples its ticket;
6. creates the ZIP and SHA-256 checksums;
7. generates GitHub build-provenance attestations;
8. uploads all assets to a draft Release and publishes it only after every step succeeds;
9. deletes the temporary keychain and credential files.

Review the workflow's notarization logs before announcing the release. Download the DMG from GitHub on a clean Mac user account and verify installation, first launch, Safari permission handling, and Touch Bar behavior.

Users can verify build provenance with:

```bash
gh attestation verify ChatGPTTouchBar-v0.3.0-macOS.dmg \
  --repo sou1213/chatgpt-touchbar
```

See GitHub's documentation on [artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations) and [immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases).

## Local packaging

`./scripts/package_release.sh 0.3.0` creates an ad-hoc-signed DMG and ZIP when no release credentials are present. This is useful for layout and installation testing only. It is deliberately separate from the public Release workflow, which refuses to publish without Developer ID signing and notarization.
