## 1. Cipher type support

- [x] 1.1 Add `sshKey` support to the shared cipher type and extend any type-based display helpers that currently assume only login, secure note, card, and identity.
- [x] 1.2 Update vault sync and persistence-facing code so SSH key ciphers are retained in local vault state instead of being skipped as unsupported types.

## 2. Vault tab filtering UI

- [x] 2.1 Add a dedicated vault tab model and selected-tab state in the vault view model for `Login`, `Note`, `Card`, `Identity`, `SSH Key`, and `Favorites`.
- [x] 2.2 Update vault filtering so the active tab and search query jointly determine `visibleCiphers`, empty-state messaging, and footer item counts.
- [x] 2.3 Render the top-level tab strip above the vault list in `VaultRootView` and keep row selection, detail presentation, and row actions working inside filtered results.
- [x] 2.4 Add `Command`-modified drag-and-drop reordering for the vault tab strip without replacing normal click selection.

## 3. Validation

- [x] 3.1 Add or update focused tests for vault filtering and SSH key retention where the current test surface allows it.
- [x] 3.2 Run `swift build` and `swift test` from `BitwardenBar/` to validate the new vault tab behavior and the added cipher-type support.
