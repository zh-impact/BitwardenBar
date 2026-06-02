## Why

All UI — login, unlock, settings, and vault browsing — currently lives inside a single NSPopover attached to the menu bar status item. Popovers are transient: clicking outside or pressing Escape dismisses them immediately. This means a user mid-login or mid-settings-edit can accidentally lose their work. Only vault browsing benefits from the lightweight popover UX; authentication and configuration flows need a persistent, non-dismissable surface.

## What Changes

- **Login and unlock flows move from the popover into dedicated `NSWindow` instances.** These windows are not dismissable by clicking outside; the user must explicitly complete or cancel the flow.
- **Settings moves from a `.sheet` inside the popover into its own `NSWindow`.** The popover vault view only needs a button to open settings; it no longer hosts the settings modal.
- **The popover continues to show vault content only.** When the user needs to log in, unlock, or configure the app, the popover closes and the appropriate window opens.
- **App activation policy shifts to `.regular` while any auth/settings window is open**, and returns to `.accessory` when all windows close and only the popover remains.

## Capabilities

### New Capabilities

- `window-presentation`: Defines how the app opens and manages separate NSWindow instances for authentication (login/unlock) and settings, including window lifecycle, activation policy, and coordination with the popover.

### Modified Capabilities

_(No existing specs are being modified at the requirements level. The existing specs for `desktop-auth-session` and `desktop-global-shortcut` remain unchanged in their behavioral contracts.)_

## Impact

- **UI layer** (`UI/Auth/`, `UI/Vault/`, `UI/RootView.swift`): LoginView and UnlockView will be hosted in windows instead of the popover; VaultRootView loses its settings sheet; RootView routing logic changes.
- **App shell** (`App/StatusBarController.swift`, `App/AppDelegate.swift`): New window management responsibilities — creating, showing, and tracking auth/settings windows; coordinating activation policy transitions.
- **New file** — a window controller or coordinator (e.g., `App/WindowCoordinator.swift`) to centralize window-vs-popover presentation logic.
- **No impact** on auth, network, crypto, storage, or sync subsystems — the change is purely presentational.
