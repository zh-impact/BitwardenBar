## 1. Shared Shortcut State

- [x] 1.1 Add a shared shortcut settings model or helper that loads `hotkey.keyCode` and `hotkey.modifiers`, validates them, and supplies the default Command-Shift-B fallback.
- [x] 1.2 Update the settings UI to read and write global shortcut values through the shared shortcut settings path instead of duplicating raw defaults handling.

## 2. Runtime Hotkey Registration

- [x] 2.1 Update the app shell to initialize `HotKeyMonitor` from the persisted shortcut settings rather than always using hard-coded defaults.
- [x] 2.2 Propagate shortcut changes from Settings to the active hotkey listener so the new shortcut works without relaunch.

## 3. Shortcut Recording Reliability

- [x] 3.1 Fix the settings recorder to explicitly acquire focus when recording begins so the next eligible key event is captured reliably.
- [x] 3.2 Keep invalid recorder input from overwriting saved shortcut values and preserve recording mode until a valid modified key shortcut is captured or recording is canceled.

## 4. Validation

- [x] 4.1 Add or update focused tests for shortcut validation and persistence behavior where the current test surface allows it.
- [x] 4.2 Run `swift build` and any targeted tests needed to confirm startup registration, live shortcut updates, and recorder validation changes compile cleanly.
