# BitwardenBar

BitwardenBar is a macOS menu bar client for Bitwarden built in Swift. The active implementation lives in the `BitwardenBar/` Swift package, which exposes a reusable `BitwardenBar` library and a thin `BitwardenBarStandalone` executable that launches the shared AppKit delegate.

This workspace also contains a small Xcode host app, OpenSpec change artifacts, and large upstream Bitwarden reference repos used to confirm protocol details. In normal development, you should expect to edit `BitwardenBar/` and treat `references/` as documentation.

## Workspace Overview

- `BitwardenBar/`: main app code, Swift package manifest, tests, and the standalone executable target.
- `BitwardenBarApp/`: thin Xcode host app that embeds the shared `BitwardenBar` library via `@NSApplicationDelegateAdaptor`.
- `openspec/`: capability specs and change artifacts for planned or in-progress work.
- `references/clients/`: official Bitwarden TypeScript clients for request, response, and protocol verification.
- `references/ios/`: official Bitwarden iOS codebase for Swift-side modeling and behavior checks.

## What The App Does

The current codebase is organized around a menu bar workflow:

- authenticate against Bitwarden using the identity and API services
- support two-step login and session unlock flows
- decrypt and cache vault data locally
- present vault items in a popover UI
- expose app settings, including global shortcut configuration

The app uses:

- AppKit `NSStatusItem` and `NSPopover` for the menu bar shell
- SwiftUI for login, unlock, vault, and settings screens
- pure Swift crypto for Bitwarden key derivation and decryption
- GRDB for the local SQLite-backed vault cache
- Keychain and `UserDefaults` for persisted account and credential state

## Quick Start

### Requirements

- macOS 13 or newer
- Xcode with Swift 5.9 toolchain support

### Build And Test

From `BitwardenBar/`:

```bash
swift build
swift test
```

To launch the standalone package executable:

```bash
cd BitwardenBar
swift run BitwardenBarStandalone
```

If you prefer the Xcode app host, open the project in `BitwardenBarApp/` and run the app target. The host app reuses the same `BitwardenBarAppDelegate` implementation as the standalone executable.

## Project Structure

### Main Runtime Code

- `BitwardenBar/Sources/BitwardenBar/App/`: app delegate, menu bar controller, service wiring, app state, and hotkey registration
- `BitwardenBar/Sources/BitwardenBar/Core/Auth/`: Bitwarden login and token flow
- `BitwardenBar/Sources/BitwardenBar/Core/Network/`: request building and API communication
- `BitwardenBar/Sources/BitwardenBar/Core/Crypto/`: key derivation and decryption primitives
- `BitwardenBar/Sources/BitwardenBar/Core/Vault/`: sync and vault processing
- `BitwardenBar/Sources/BitwardenBar/Core/Storage/`: account state, keychain, hotkey settings, and cached vault storage
- `BitwardenBar/Sources/BitwardenBar/UI/`: login, unlock, vault, root, and settings views

### Entry Points

- `BitwardenBar/Sources/BitwardenBarStandalone/main.swift`: standalone executable entry point
- `BitwardenBar/Sources/BitwardenBar/App/AppDelegate.swift`: shared AppKit lifecycle entry used by both the standalone target and the Xcode host app
- `BitwardenBarApp/BitwardenBarApp/BitwardenBarAppApp.swift`: thin SwiftUI app wrapper around the shared delegate

### Tests

Unit tests live in `BitwardenBar/Tests/BitwardenBarTests/` and currently cover core areas such as auth, crypto, cipher handling, TOTP, and hotkey settings.

## Development Notes

- The active package product is `BitwardenBar`; the Xcode host app should stay thin.
- `setup.sh` exists to clone and patch a vendored `sdk-swift` copy for reference use. The current app does not depend on that SDK at runtime.
- `references/` is intentionally large and should usually be treated as read-only support material.
- `openspec/` documents capability specs and change history for features such as desktop auth sessions, global shortcuts, and vault detail presentation.

## High-Value Files

- `BitwardenBar/Sources/BitwardenBar/App/StatusBarController.swift`: popover lifecycle and menu bar behavior
- `BitwardenBar/Sources/BitwardenBar/App/ServiceContainer.swift`: application wiring and service construction
- `BitwardenBar/Sources/BitwardenBar/Core/Auth/AuthService.swift`: login, token, and profile flow
- `BitwardenBar/Sources/BitwardenBar/Core/Crypto/BWCrypto.swift`: Bitwarden cryptography primitives
- `BitwardenBar/Sources/BitwardenBar/Core/Vault/SyncService.swift`: vault sync and decryption pipeline
- `BitwardenBar/Sources/BitwardenBar/UI/Auth/LoginView.swift`: login and two-factor UI flow
- `BitwardenBar/Sources/BitwardenBar/UI/Vault/VaultRootView.swift`: top-level vault presentation

## Suggested Workflow

1. Make changes in `BitwardenBar/` first.
2. Use `swift build` or `swift test` from `BitwardenBar/` for quick validation.
3. Cross-check protocol-sensitive changes against `references/clients/` and `references/ios/` before changing auth or crypto behavior.
4. Update or consult `openspec/` when a change affects documented capabilities or active work items.
