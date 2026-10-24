# Decrypt App Store for macOS

Native SwiftUI desktop client for ipatool and fairplay-decrypt. Requires macOS 26 or newer; developed and reviewed on macOS 27 with genuine system Liquid Glass controls.

## Build and run

From the repository root, run `./script/build_and_run.sh`. Xcode with Swift 6.2+ is required. `--build` stages an ad-hoc signed app in `dist/`; `--verify` launches and checks its process. `--debug`, `--logs`, and `--telemetry` support local investigation.

The app uses separately installed command-line tools. It does not bundle an account, credential, Python environment, ipatool, or downloaded packages.

In Settings, choose:

- An installed ipatool executable (tested with 2.7.0), authenticated interactively in Terminal. The existing session remains in Keychain; the GUI never asks for a password.
- A Python interpreter with this repository’s `requirements.txt` installed.
- A fairplay-decrypt checkout built with `make`.
- Your matching account’s raw 16-byte credential file with 0600 permissions. Keep its containing directory private (0700).
- A local output directory.

Only the credential path is persisted in private app settings; credential bytes are passed to neither logs nor the app bundle. The decryptor reads the credential locally using its existing `--credential` option.

## Workflow and limits

The storefront opens with Apple’s live US top-free chart, featured cards, and platform browsing. App artwork comes from Apple’s public catalog. Historical releases show display versions by default, resolve in pages of 12, and offer optional external IDs.

Search iPhone, iPad, Mac, Watch, Vision or Apple TV. Select a result and optionally load historical external version IDs. Downloads require an existing license; the client never passes `--purchase`. Apple may decline old versions even when they appear in the version list.

Jobs run sequentially and preserve source packages. Each receives a unique output folder. Open IPA imports an existing archive without copying or replacing it. Activity shows stages, per-binary decryption progress, cancellation, and errors. Library retains completed output paths across launches. Jobs interrupted by app termination are marked interrupted on next launch.

Mac packages are download-only. IPA decryption supports only the formats handled by upstream; platform availability does not guarantee decryption. Every output IPA is independently checked for ZIP CRC, unchanged member inventory, main app identity and encryption commands in all thin/fat Mach-O slices. Partial archives retain an explicit warning and a per-slice report. Static validation does not prove installability or runtime compatibility.

No raw subprocess output is persisted or displayed. Failures show bounded, actionable descriptions. Logs from manual CLI runs may contain account information and should remain private.

## Verification

`./script/test.sh` runs the Python and Swift suites. It builds test bundles in a temporary directory to avoid Finder metadata injected by synced folders. The Swift suite checks cancellation, concurrent pipe draining, JSON decoding and diagnostic privacy.

`python3 -m unittest discover -s tests -v` exercises the validator, including mixed encrypted/clear fat slices and malformed inputs. `python3 macos/Resources/audit.py OUTPUT.ipa --reference ORIGINAL.ipa` runs the same independent audit used by the app.

The DMG is a local development artifact, ad-hoc signed and not notarized. It requires the external tools configured above. No binaries or user packages should be attached to a public pull request.

## Branded installer

Version 0.1.1 includes the glass app icon and a Finder drag-to-Applications layout. See [branding and packaging instructions](../docs/BRANDING.md) for reproducible assets and disk image generation. The DMG does not contain credentials, an account session, or user archives.
