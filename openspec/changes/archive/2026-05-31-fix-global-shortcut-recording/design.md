## Context

BitwardenBar exposes a configurable global shortcut in `SettingsView`, persists the selected key code and modifiers in `UserDefaults`, and uses `HotKeyMonitor` inside `StatusBarController` to listen for the shortcut that toggles the popover. Today those pieces are not coordinated reliably: the app shell creates `HotKeyMonitor` with default values, and the recorder path depends on focus-sensitive local key capture inside the settings UI. This is a cross-cutting macOS shell change because it touches runtime activation, local settings capture, and persistence boundaries.

## Goals / Non-Goals

**Goals:**
- Ensure one persisted shortcut definition is used consistently by the settings UI and the runtime hotkey monitor.
- Apply shortcut changes without requiring an app relaunch.
- Make shortcut recording reliable for valid modified key combinations and reject invalid recordings without corrupting saved state.
- Preserve the existing default shortcut as a fallback when saved shortcut data is absent or invalid.

**Non-Goals:**
- Changing the accessibility permission model or replacing the CGEventTap-based listener.
- Adding support for modifier-only shortcuts or shortcut chords.
- Introducing a third-party shortcut recording dependency.

## Decisions

### Use a shared shortcut settings abstraction as the single source of truth
The app should move shortcut loading and persistence behind a small shared abstraction owned by the app-shell/settings boundary instead of letting `SettingsView` and `StatusBarController` touch raw defaults independently. This keeps the default fallback, validation, and value shape in one place.

Alternative considered: continue reading `@AppStorage` in SwiftUI and separately reconstruct the same values in the app controller. Rejected because the current bug exists precisely because runtime registration and settings persistence have already drifted apart.

### Reconfigure the active hotkey listener when settings change
`StatusBarController` should start `HotKeyMonitor` from the persisted shortcut and observe subsequent shortcut changes so the active listener is updated immediately. The implementation can either update the monitor in place or restart the event tap when needed, but the observable behavior must be that the new shortcut works without relaunch.

Alternative considered: only apply new shortcut values on next launch. Rejected because it leaves the visible settings action misleading and does not solve the primary user-facing defect.

### Keep recording local to the settings UI, but make focus acquisition explicit and validation strict
The settings recorder should continue using a lightweight local AppKit bridge rather than introducing a package, but entering recording mode must explicitly route focus to the capture view so the next eligible key event is seen reliably. Recorded shortcuts must include at least one modifier and one non-modifier key before saved state is updated.

Alternative considered: add a dependency such as a dedicated shortcut recorder control. Rejected because the existing UI only needs predictable first-responder handling and validation, not a broader dependency surface.

## Risks / Trade-offs

- [Recorder focus still depends on popover/window lifecycle] -> Mitigation: keep recording scoped to the active settings window and validate with a focused build/test pass against the settings surface.
- [Immediate reconfiguration could temporarily leave no active listener if the monitor is restarted incorrectly] -> Mitigation: keep fallback defaults in the shared shortcut model and update listener state on the main actor.
- [Invalid persisted values from older builds may still exist in defaults] -> Mitigation: validate persisted key/modifier pairs on load and fall back to the default shortcut when validation fails.
