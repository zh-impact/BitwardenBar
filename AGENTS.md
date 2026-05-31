# BitwardenBar Agent Guide

This workspace has one active app and two large read-only reference repos.

- `BitwardenBar/`: the app to change.
- `references/clients/`: official TypeScript Bitwarden clients, used to confirm protocol details.
- `references/ios/`: official Swift/iOS code, used as a Swift-side reference.

Prefer changing `BitwardenBar/` only. Treat both `references/` trees as documentation unless a task explicitly asks to edit them.

## Build and validation

- Build from `BitwardenBar/` with `swift build`.
- Run tests from `BitwardenBar/` with `swift test`.
- The package now exposes a reusable `BitwardenBar` library product plus a thin standalone executable declared in [BitwardenBar/Package.swift](BitwardenBar/Package.swift).
- `setup.sh` exists mainly to clone and patch `vendor/sdk-swift` for reference use. The current app does not depend on that SDK at runtime.

## High-value code map

- App shell and menu bar behavior: [BitwardenBar/Sources/BitwardenBar/App](BitwardenBar/Sources/BitwardenBar/App)
- Auth flow: [BitwardenBar/Sources/BitwardenBar/Core/Auth/AuthService.swift](BitwardenBar/Sources/BitwardenBar/Core/Auth/AuthService.swift)
- Network layer: [BitwardenBar/Sources/BitwardenBar/Core/Network](BitwardenBar/Sources/BitwardenBar/Core/Network)
- Crypto primitives: [BitwardenBar/Sources/BitwardenBar/Core/Crypto/BWCrypto.swift](BitwardenBar/Sources/BitwardenBar/Core/Crypto/BWCrypto.swift)
- Vault sync and decryption: [BitwardenBar/Sources/BitwardenBar/Core/Vault/SyncService.swift](BitwardenBar/Sources/BitwardenBar/Core/Vault/SyncService.swift)
- Persistence: [BitwardenBar/Sources/BitwardenBar/Core/Storage](BitwardenBar/Sources/BitwardenBar/Core/Storage)
- Login and 2FA UI: [BitwardenBar/Sources/BitwardenBar/UI/Auth/LoginView.swift](BitwardenBar/Sources/BitwardenBar/UI/Auth/LoginView.swift)

## Current architecture

- This is a macOS status bar app built with `NSStatusItem` + `NSPopover` and SwiftUI views.
- The app uses pure Swift crypto in [BitwardenBar/Sources/BitwardenBar/Core/Crypto/BWCrypto.swift](BitwardenBar/Sources/BitwardenBar/Core/Crypto/BWCrypto.swift), not the Bitwarden SDK.
- The only package dependency is `GRDB.swift` for the local SQLite vault cache.
- Account metadata is stored in `UserDefaults`; tokens and keys go through Keychain; vault data is cached in SQLite via GRDB.
- `CryptoService` keeps unlocked session material in memory per `userId`.

## Bitwarden protocol details already verified

These details were confirmed against `references/clients/` and should be preserved unless Bitwarden changes the protocol.

- Prelogin must use the identity server, not the API server.
- `/connect/token` must be `application/x-www-form-urlencoded`, not JSON.
- Password `/connect/token` requests should not send `Auth-Email`; current Bitwarden iOS references explicitly treat that header as deprecated for password login.
- Token requests must send `Device-Type: 7` as an HTTP header, not only `deviceType=7` in the form body.
- Token requests should send `Accept: application/json`.
- `Bitwarden-Client-Name` and `Bitwarden-Client-Version` should not be attached to the token endpoint request itself.
- Other app/API requests should send `Device-Type: 7`, `Bitwarden-Client-Name: desktop`, and a current desktop version. The app currently uses `2026.5.0`.
- Token response fields use mixed casing: OAuth fields are snake_case like `access_token`, but Bitwarden decryption fields are PascalCase like `Key`, `PrivateKey`, `KdfIterations`, `ResetMasterPassword`.
- Two-factor-required responses come back as HTTP 400 with `TwoFactorProviders2`.

## Login and 2FA flow notes

- The primary login path is: prelogin -> token request -> profile request -> unlock vault -> initial sync.
- The currently verified happy path is: account password login -> manual 2FA -> successful vault login -> trigger lock -> unlock with master password -> success.
- `GetProfileRequest` supports an explicit access-token override so login can fetch the profile before an active account exists in `AccountStore`.
- The 2FA screen in [BitwardenBar/Sources/BitwardenBar/UI/Auth/LoginView.swift](BitwardenBar/Sources/BitwardenBar/UI/Auth/LoginView.swift) has separate state-aware submit handling. Do not collapse it back to always calling the first-step login action.
- If 2FA appears to succeed but the UI stays on the code-entry screen, check `LoginView` button wiring first.
- If login fails with `Session expired. Please log in again.` immediately after 2FA, check whether a post-token authenticated request is incorrectly depending on `activeAccount` instead of the fresh access token.
- If login fails with missing key material, inspect `IdentityTokenResponse` decoding before changing crypto.

## Crypto constraints

- PBKDF2-SHA256 is implemented.
- Argon2id currently throws `argon2idNotSupported`; do not silently fake support.
- Vault unlocking depends on the encrypted user key (`Key`) and encrypted private key (`PrivateKey`) returned by login.
- The current pure Swift flow is: derive master key -> stretch to enc/mac keys -> decrypt server user key -> decrypt vault contents.

## Known macOS UI constraints

- The app uses `.accessory` activation policy at rest and temporarily switches to `.regular` when showing the popover so text input and paste work.
- `StatusBarController.showPopover()` must keep making the window key; otherwise paste and keyboard interaction regress.
- Global shortcut handling now uses Carbon `RegisterEventHotKey`, not the old Accessibility-dependent event tap path.

## Current rough edges

- Master-password re-unlock now depends on the encrypted user key/private key captured during a successful login and stored in Keychain. If older local state predates this change, one fresh login may still be required to seed that key material.
- Biometric unlock is also incomplete because decrypted user-key/private-key storage for that path is not implemented.
- When fixing auth bugs, prefer checking the exact response contract against [references/clients/libs/common/src/auth/models/response/identity-token.response.ts](references/clients/libs/common/src/auth/models/response/identity-token.response.ts) and [references/ios/BitwardenShared/Core/Auth/Models/Response/IdentityTokenResponseModel.swift](references/ios/BitwardenShared/Core/Auth/Models/Response/IdentityTokenResponseModel.swift) before changing crypto logic.

## Working style for this repo

- Start from the narrowest owning file in `BitwardenBar/`, not from the reference repos.
- Use `references/clients/` to confirm network headers, request bodies, response shapes, and error formats.
- Use `references/ios/` to confirm Swift naming and response-model expectations when the TypeScript client is too indirect.
- Keep fixes minimal and protocol-accurate. Many recent auth bugs were caused by tiny mismatches in headers, form encoding, response decoding, or UI submit routing.
