## Why

BitwardenBar's authentication, unlock, and vault interaction behavior has changed materially during recent debugging, but the repository still has no OpenSpec record of those behavior contracts. Capturing the current state now reduces the risk of reintroducing protocol mismatches, broken unlock flows, or unstable vault interactions during later cleanup.

## What Changes

- Document the current password login flow, including prelogin, token exchange, 2FA continuation, profile fetch, unlock, and initial sync.
- Document the response-decoding and request-shaping requirements needed to stay compatible with Bitwarden's mixed-case API contracts.
- Document the master-password unlock behavior, including encrypted key-material persistence and refresh fallback through the authenticated profile endpoint.
- Document the vault list detail-presentation behavior and the UI-state lifetime constraints that avoid row-selection crashes.

## Capabilities

### New Capabilities
- `desktop-auth-session`: Desktop login, 2FA, session establishment, and master-password unlock behavior for BitwardenBar.
- `desktop-vault-detail-presentation`: Stable selection and detail presentation behavior for vault list items in the menu bar UI.

### Modified Capabilities
- None.

## Impact

- Affected code: `BitwardenBar/Sources/BitwardenBar/Core/Auth`, `BitwardenBar/Sources/BitwardenBar/Core/Network`, `BitwardenBar/Sources/BitwardenBar/Core/Storage`, `BitwardenBar/Sources/BitwardenBar/UI/Auth`, `BitwardenBar/Sources/BitwardenBar/UI/Vault`.
- Affected systems: Bitwarden identity and profile API integration, Keychain-backed session recovery, SwiftUI menu bar interaction lifecycle.
- Key references: `references/clients/` and `references/ios/` remain the protocol source of truth for auth and response contracts.