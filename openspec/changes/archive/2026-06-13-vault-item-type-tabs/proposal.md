## Why

BitwardenBar's vault popover currently exposes a single flat list, which makes large vaults slow to scan when the user only wants a specific item type or their favorites. This matters now because the requested top-level filters change visible vault behavior and also surface an existing gap: the app currently drops SSH key items during sync instead of letting the vault UI categorize them.

## What Changes

- Add a tab strip above the vault list for `Login`, `Note`, `Card`, `Identity`, `SSH Key`, and `Favorites`.
- Allow users to hold `Command` and drag vault tabs to reorder them within the current vault view.
- Filter the visible vault list, empty state, and item count based on the selected tab while preserving the existing search behavior within the active filter.
- Extend vault item type handling so synced SSH key items are retained and can participate in the new vault filters instead of being rejected as unknown cipher types.
- Keep existing row selection, detail presentation, and row actions working inside filtered vault results.

## Capabilities

### New Capabilities
- `desktop-vault-type-tabs`: Top-level vault tabs for type-specific and favorites-specific filtering in the menu bar vault UI.

### Modified Capabilities
None.

## Impact

- Affected subsystems: vault UI, vault sync, shared cipher models, and local storage mappings for cipher types.
- Affected code is expected under `UI/Vault`, `Core/Vault`, and `Shared/Models` in `BitwardenBar/`.
- The vault tab strip now has modifier-aware drag interaction in addition to click-based tab selection.
- No external API contract changes are required, but the app must correctly preserve Bitwarden cipher types already present in synced vault data.
