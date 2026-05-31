## Context

BitwardenBar is a pure Swift macOS status bar client that implements Bitwarden login and vault decryption without the official SDK at runtime. Recent bug fixing established several protocol-accurate behaviors: the token endpoint requires form encoding and identity-server routing, 2FA continuation must stay on a separate UI submission path, post-token requests sometimes need a fresh access-token override, encrypted login key material must survive into later unlock attempts, and vault item detail presentation must not be tied to the lifetime of lazily recycled row views.

The change is cross-cutting because it spans the network layer, auth service, Keychain persistence, unlock flow, and SwiftUI presentation state. The goal here is not to redesign those systems, but to preserve the decisions already validated by implementation work.

## Goals / Non-Goals

**Goals:**
- Record the current desktop auth/session behavior as a capability contract instead of leaving it implicit in code and chat history.
- Preserve the protocol decisions that make Bitwarden identity and profile responses decode correctly in the pure Swift client.
- Preserve the unlock strategy that uses stored encrypted key material and refreshes from `/accounts/profile` when local state is stale.
- Preserve the UI-lifecycle decisions that keep login, unlock, and vault-detail presentation stable in a menu bar app.

**Non-Goals:**
- Introduce biometric private-key storage or complete biometric unlock.
- Redesign the broader data model for accounts, vault items, or sync.
- Specify every vault field or full Bitwarden object graph beyond the behavior touched by this work.

## Decisions

### 1. The network layer uses a single mixed-case JSON decoding strategy.

Bitwarden responses mix snake_case OAuth fields with PascalCase account and crypto fields, and profile/sync payloads may include dates with or without fractional seconds. The design records a single network-decoder policy that accepts snake_case, PascalCase, and camelCase keys and handles both ISO8601 date variants.

Why this over per-model `CodingKeys` patches:
- The failures were systemic, not isolated to one response type.
- Centralizing the policy reduces the chance of fixing one response and missing the next one.
- This matches the official iOS client's `pascalOrSnakeCaseDecoder` approach more closely.

Alternative considered:
- Continue patching individual response models with explicit `CodingKeys`.
  Rejected because it is brittle and easy to regress as more Bitwarden response shapes are touched.

### 2. Login is modeled as a five-step flow with explicit post-token continuity.

The intended desktop login sequence is:

1. prelogin
2. token request
3. authenticated profile request
4. vault unlock
5. initial sync

After the token response, the client may need to fetch profile data before an active account is fully persisted. The design therefore records that authenticated requests in this phase may use an explicit access-token override rather than depending on `activeAccount` state.

Alternative considered:
- Require `AccountStore.activeAccount` to exist before any authenticated follow-up request.
  Rejected because it caused the immediate post-2FA "Session expired" failure path.

### 3. Password unlock depends on persisted encrypted login key material, with profile refresh as a recovery path.

The desktop client persists the encrypted user key and encrypted private key returned by login into Keychain. Later password unlock attempts use that stored material to derive the vault key locally. If the local material is missing or fails integrity verification, the client falls back to `/accounts/profile` using the active token, refreshes `Key` and `PrivateKey`, stores them, and retries unlock.

Why this over forcing full re-login every time local material is stale:
- It preserves a normal locked/unlocked desktop experience.
- It allows recovery from older local states that predate encrypted-key persistence.
- It keeps the unlock path aligned with how Bitwarden models master-password-based session recovery.

Alternative considered:
- Make master-password unlock unsupported until full biometric/private-key storage work is complete.
  Rejected because password unlock is already part of the visible UI contract.

### 4. Vault item details are presented from list-level state, not row-owned presentation state.

Vault list rows are rendered inside a lazy stack. Detail presentation is driven from a single list-level selected cipher rather than each row owning a popover state. This avoids lifetime bugs where SwiftUI recycles a row while the detail presentation still references it.

Alternative considered:
- Continue using per-row popovers.
  Rejected because it produced deallocated-reference crashes when rows were recycled.

### 5. Login, unlock, and post-login sync UI state is main-actor constrained.

The design records that state driving SwiftUI views, especially loading indicators, error messages, and sync status, must be updated on the main actor. This is particularly important in a menu bar app where multiple async tasks fire around 2FA completion, unlock, and auto-sync.

Alternative considered:
- Allow background tasks to update local state directly where it "usually works".
  Rejected because it risks runtime UI/threading faults that surface only under interaction timing.

## Risks / Trade-offs

- [Older local state may still lack the encrypted login key material] -> Mitigation: refresh from `/accounts/profile` during unlock before forcing a new login.
- [Bitwarden may change auth/profile response contracts again] -> Mitigation: keep `references/clients/` and `references/ios/` as the protocol reference and verify against them before changing crypto logic.
- [Biometric unlock remains incomplete] -> Mitigation: keep it explicitly out of scope for this change and preserve password unlock as the supported recovery path.
- [The capabilities may still under-document future auth edge cases such as Argon2id or Key Connector] -> Mitigation: capture those in follow-up changes instead of bloating this retrospective change.

## Migration Plan

1. Treat this change as a retrospective documentation baseline for behavior already implemented.
2. Review the recorded capabilities against current code before archiving or syncing into main specs.
3. Split future work such as biometric unlock completion or broader account cryptographic state into separate changes.

## Open Questions

- Should a future capability explicitly cover biometric unlock and decrypted private-key storage, or should that stay implementation-defined until the path is complete?
- Should menu bar UI lifecycle guarantees be expanded into a broader desktop-shell capability, or remain scoped to vault detail presentation for now?