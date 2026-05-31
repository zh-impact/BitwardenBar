## Why

BitwardenBar already exposes Touch ID in the locked-state UI, but the biometric path is incomplete and currently fails before it can restore an unlocked vault session. Closing that gap now improves unlock reliability and removes a visible dead-end in the macOS menu bar experience.

## What Changes

- Implement end-to-end biometric unlock so a previously logged-in account can unlock the vault without re-entering the master password.
- Persist the key material required for biometric re-entry during login and later successful local unlock or lock transitions, and use it to rehydrate the local crypto session after successful biometric authentication.
- Tighten locked-state UI behavior so biometric unlock is only offered when both the device and the account have the required stored material.
- Preserve master-password unlock as the fallback path when biometric enrollment, permissions, or stored local material are unavailable.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `desktop-auth-session`: Extend the desktop unlock requirements to cover successful biometric unlock, required local key-material persistence, and fallback behavior when biometrics cannot complete.

## Impact

- Affected code: `BitwardenBar/Sources/BitwardenBar/Core/Auth`, `BitwardenBar/Sources/BitwardenBar/Core/Crypto`, `BitwardenBar/Sources/BitwardenBar/Core/Storage`, `BitwardenBar/Sources/BitwardenBar/UI/Auth`.
- Affected systems: LocalAuthentication integration, Keychain-backed secret storage, in-memory vault session restoration, locked-state unlock UI.
- Dependencies and constraints: macOS biometric availability and entitlements, existing Bitwarden encrypted key-material handling, and the current password-unlock session contract.
