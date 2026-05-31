## Why

The app currently exposes a configurable global shortcut in Settings, but the runtime hotkey listener still behaves as if the shortcut were fixed and users can also fail to record a replacement shortcut at all. This matters now because the broken shortcut path is a macOS UI stability issue in one of the app's primary entry points.

## What Changes

- Add a new desktop capability that defines how the app records, persists, restores, and registers the global shortcut used to show or hide the vault popover.
- Require the app shell to load the persisted shortcut at startup and apply shortcut changes without requiring a relaunch.
- Require the settings shortcut recorder to capture valid key-plus-modifier combinations reliably while the settings UI is active.
- Require the app to fall back to the default shortcut when no saved shortcut is available or a saved shortcut is invalid.

## Capabilities

### New Capabilities
- `desktop-global-shortcut`: Defines the user-visible behavior for recording, persisting, restoring, and using the menu bar app's global shortcut.

### Modified Capabilities
- None.

## Impact

- Affected code in `BitwardenBar/Sources/BitwardenBar/App` for shortcut registration and popover activation.
- Affected code in `BitwardenBar/Sources/BitwardenBar/UI/Settings` for shortcut recording and settings persistence.
- Affected persistence behavior in `UserDefaults` for saved shortcut state.
- No external API or dependency changes.
