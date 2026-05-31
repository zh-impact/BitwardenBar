## Context

BitwardenBar already has a partial biometric unlock path across `AuthService`, `KeychainRepository`, `CryptoService`, and `UnlockView`. The locked-state UI can show a Touch ID button, and `CryptoService` already supports restoring a vault session from a pre-decrypted user key, but `AuthService.unlockWithBiometrics` stops at a placeholder because the app does not yet persist and retrieve the full local material needed to complete that flow safely.

This change is security-sensitive and cross-cutting. It affects how local secrets are stored in Keychain, how unlock state is restored without the master password, and when the menu bar UI advertises biometric unlock as available.

## Goals / Non-Goals

**Goals:**
- Complete the existing biometric unlock path for previously logged-in accounts without changing Bitwarden's network protocol.
- Store the local vault bootstrap material in a way that is gated by macOS biometric authentication rather than plain app-controlled state.
- Keep password unlock as the supported fallback when biometric authentication or stored local material is unavailable.
- Ensure the locked-state UI only presents biometric unlock when the account can satisfy the local prerequisites.

**Non-Goals:**
- Redesign password login, 2FA, token refresh, or sync behavior.
- Introduce Bitwarden SDK runtime dependencies or new server-side APIs.
- Add support for unsupported KDF modes such as Argon2id.
- Define a user-facing settings surface for opting in or out of biometric unlock.

## Decisions

### 1. Biometric unlock prefers a dedicated biometric-protected Keychain item, with a generic local fallback.

The app keeps the existing encrypted user key and encrypted private key storage used by password unlock, and it additionally persists the decrypted 64-byte user key in two local forms: a dedicated biometric-protected Keychain item and a generic local `userKey` fallback. Biometric unlock prefers the biometric-protected item, but the locked-state UI and restore flow may fall back to the generic local key when the stricter existence probe is unavailable or a previous session predated the dedicated item.

Why this over storing only one copy of the key:
- The dedicated biometric-protected item remains the preferred security boundary for biometric re-entry.
- The generic local key keeps the UI and unlock path usable after later successful password unlocks, manual lock transitions, and older seeded sessions where the stricter probe may not report availability reliably.
- This matches the current implementation boundary because `CryptoService.unlockVaultWithKey` already restores the in-memory session from a decrypted key regardless of which local store supplied it.

Alternative considered:
- Require the biometric-protected item as the only valid source for both UI availability and unlock.
  Rejected because the current menu bar implementation needs a generic local fallback to avoid hiding a working biometric unlock path when the dedicated probe is unavailable.

### 2. A successful biometric unlock restores the local crypto session entirely offline.

After successful LocalAuthentication, `AuthService` reads the biometric-protected decrypted user key and may fall back to the generic stored `userKey` when needed, then calls `CryptoService.unlockVaultWithKey`. The biometric unlock path does not depend on `/accounts/profile`, token refresh, or master-password re-derivation.

Why this over fetching fresh material from the network during biometric unlock:
- Unlock should remain fast and reliable while the app is locked, including when the network is unavailable.
- The local decrypted vault key is already sufficient for the current crypto session model.
- It avoids coupling a local biometric action to token freshness or active-account request routing.

Alternative considered:
- Fall back to `/accounts/profile` to recover key material after biometric authentication.
  Rejected because it makes biometric unlock dependent on network state and does not remove the need to persist local unlock material.

### 3. The locked-state UI is availability-driven, with a practical fallback.

`UnlockView` shows the biometric action only when the device can evaluate biometric policy and the account has either the dedicated biometric-protected key or the generic local `userKey`. If biometric material has been invalidated or removed, the UI falls back to master-password unlock rather than advertising a path that can only end in an error.

Why this over a stricter dedicated-item-only gate:
- The current behavior exposes a visible dead-end.
- The user-facing contract is stronger when the button implies a realistic success path.
- It keeps the UI aligned with the actual restore path implemented in `AuthService`, which already accepts the generic fallback key.

Alternative considered:
- Keep the button visible whenever biometrics are available and surface missing-material errors only after tap.
  Rejected because it preserves the current failure mode instead of fixing it.

### 4. Login, password unlock, and manual lock can all seed later biometric unlock; logout removes it.

When a live vault session already exists, the app seeds the generic local biometric fallback key from that session during login, after successful password unlock, and before manual lock clears in-memory crypto state. Logging out removes the biometric-protected decrypted key and the generic local fallback alongside other account-bound secrets so the account no longer leaves local unlock material behind.

Why this split:
- Lock and logout represent different user intents.
- Biometric unlock requires local persistence across lock events, and older sessions may need the generic fallback to make the UI path visible again.
- Logout should remain the boundary that clears recoverable account secrets from the device.

Alternative considered:
- Delete biometric material on every lock.
  Rejected because it would make biometric unlock impossible after the first lock event.

## Risks / Trade-offs

- [Biometric-enrollment changes can invalidate stored biometric-protected items] -> Mitigation: treat invalidated items as unavailable, remove stale material, and fall back to master-password unlock.
- [Older accounts may not have biometric material seeded yet] -> Mitigation: keep password unlock available and seed local biometric material on the next successful password-based login, unlock, or manual lock transition that still has a live vault session.
- [The current dedicated biometric-key existence check can be stricter than the actual restore path] -> Mitigation: use the generic local `userKey` as a fallback for both UI availability and later biometric restore.
- [Keychain access-control plumbing adds platform-specific complexity] -> Mitigation: keep the new logic isolated in `KeychainRepository` and leave network and vault-decryption code paths unchanged.

## Migration Plan

1. Add dedicated KeychainRepository support for saving, reading, and deleting a biometric-protected decrypted user key per account.
2. Seed the generic local fallback key whenever a live vault session exists after login, password unlock, or manual lock.
3. Update `AuthService.unlockWithBiometrics` and `UnlockView` to prefer the dedicated biometric key and fall back to the generic local key when needed.
4. Broaden password unlock recovery so crypto unlock failures refresh encrypted server key material before requiring a new login.
5. Clear biometric material on logout while preserving it across lock events.
6. Validate the updated auth-session behavior with focused tests and an OpenSpec status check before implementation begins.

## Open Questions

- Does the current product want biometric unlock enabled automatically for eligible accounts, or should that remain an implementation default until a settings surface exists?
