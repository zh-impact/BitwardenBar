## Context

BitwardenBar currently hosts login, unlock, settings, and vault browsing inside a single menu bar popover. That coupling is acceptable for passive vault browsing, but it is a poor fit for flows that require sustained text input, multi-step decisions, or deliberate cancellation. The current popover can dismiss when the user clicks elsewhere or presses Escape, which interrupts authentication and settings edits and forces the UI to rebuild transient state.

This change is presentational rather than protocol-facing. Auth, crypto, sync, and persistence behavior should remain unchanged; the work is to move login, unlock, and settings into dedicated `NSWindow` instances while leaving the popover focused on vault browsing. Because the app normally runs with the `.accessory` activation policy, the design also needs explicit control over when the app becomes a foreground app so windowed flows can accept input reliably.

## Goals / Non-Goals

**Goals:**
- Present login and unlock in dedicated windows that stay open until the user completes or explicitly cancels the flow.
- Present settings in a separate window instead of a sheet owned by popover content.
- Keep the popover dedicated to vault content and close it when a windowed auth or settings flow begins.
- Centralize presentation ownership so popover state, window state, and activation policy transitions are coordinated in one place.
- Preserve the current auth/session behavior and avoid changes to Bitwarden protocol handling.

**Non-Goals:**
- Changing login, unlock, sync, crypto, or storage contracts.
- Introducing new authentication methods or altering existing validation/error handling semantics.
- Reworking vault browsing behavior beyond removing settings presentation from the popover.
- Defining new protocol or persistence requirements for auth state.

## Decisions

### 1. Introduce a single app-level window coordinator

Presentation state should be owned above SwiftUI view instances by an AppKit-aware coordinator responsible for showing and closing the popover, login window, unlock window, and settings window. The current issue is not inside `LoginView` or `SettingsView`; it is that transient UI surfaces are deciding flows that should outlive the popover. A single coordinator gives one authority for:

- which surface is currently active,
- whether the app should be `.regular` or `.accessory`,
- how to prevent duplicate windows of the same kind,
- and how completion/cancellation returns the user to the appropriate next surface.

Alternative considered: let each SwiftUI root view present its own window or sheet. This was rejected because it keeps lifecycle logic fragmented across transient view trees and makes activation-policy cleanup easy to miss.

### 2. Treat auth/settings as mutually exclusive modal-style flows above the popover

When login, unlock, or settings begins, the popover should close first and the corresponding window should open. These windows are persistent app surfaces, not attachments to the status item. They should remain visible until the user finishes or cancels, after which the coordinator decides whether to reopen the vault popover, leave the app idle, or advance into the next required auth state.

Alternative considered: leave the popover open behind a window or reopen it immediately. This was rejected because it creates competing sources of truth for the current UI state and complicates keyboard focus and activation transitions.

### 3. Use one window per flow type with reuse over uncontrolled recreation

Each flow type should have a stable owning window instance or controller path so repeated opens bring the existing window forward instead of stacking duplicates. This keeps settings edits and auth input state predictable and reduces coordination bugs around closing the last window. Reuse also matches the product intent: there is only one active account/auth context and one settings surface at a time.

Alternative considered: create a fresh `NSWindow` on every request. This was rejected because accidental duplicates would fragment flow state and make activation-policy bookkeeping harder.

### 4. Promote the app to `.regular` only while any standalone window is open

The app should switch to `.regular` before presenting a login, unlock, or settings window so the window can become key, receive keyboard input, and participate in standard macOS window behavior. Once all standalone windows are closed, the app should return to `.accessory` so the menu bar utility behaves like a background status item again.

This rule should be driven by coordinator-owned window count/state rather than scattered per-view calls. A central rule prevents mismatches where one flow opens the app as `.regular` and another path forgets to restore `.accessory`.

Alternative considered: keep the app permanently `.regular`. This was rejected because it changes the product’s menu bar utility behavior more broadly than necessary.

### 5. Keep view models and service contracts unchanged; adapt only presentation wiring

Login, unlock, and settings views should continue to consume their existing state and service dependencies. The implementation should move hosting responsibility, not redefine the underlying behavior. Any new integration points should be limited to callbacks/events that tell the coordinator when a flow completes, cancels, or transitions to another surface.

Alternative considered: rewrite auth routing around a new app-wide state machine. This was rejected for this change because the proposal is explicitly about window-based presentation, and a broader routing rewrite would increase risk without being required.

## Risks / Trade-offs

- [Window/popup state divergence] -> Mitigation: make the coordinator the only owner of presentation transitions and close the popover before opening a standalone window.
- [Activation policy gets stuck in `.regular`] -> Mitigation: derive policy from coordinator-managed open-window state and restore `.accessory` when the last standalone window closes.
- [Duplicate windows create conflicting flow state] -> Mitigation: reuse one window per flow type and focus existing windows instead of creating new ones.
- [Auth success/cancel paths reopen the wrong surface] -> Mitigation: model explicit post-close outcomes in the coordinator rather than letting each view decide independently.
- [Implementation drifts into auth logic changes] -> Mitigation: keep service/view-model APIs stable and validate behavior with UI-focused checks, not protocol changes.
