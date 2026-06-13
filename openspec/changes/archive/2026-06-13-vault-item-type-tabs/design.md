## Context

BitwardenBar currently renders the vault as one searchable list in `VaultRootView`, with `VaultViewModel` owning `allCiphers`, `visibleCiphers`, and the sync/search refresh flow. The requested top-of-list tabs change user-visible vault behavior in the popover, and one requested tab, `SSH Key`, exposes a model gap because `SyncService` currently skips any cipher whose `type` is not one of the four enum cases in `CipherType`.

The change crosses UI, view-model filtering, and sync/model layers, but it does not require Bitwarden protocol changes. The local vault store persists whole `Cipher` values as JSON blobs, so adding another supported enum case does not require a schema migration.

## Goals / Non-Goals

**Goals:**
- Add a compact tab strip above the vault list for `Login`, `Note`, `Card`, `Identity`, `SSH Key`, and `Favorites`.
- Let users hold `Command` and drag tabs to reorder the tab strip within the active vault view.
- Make the active tab and search query compose into a single visible-results pipeline that also drives the footer count and empty state.
- Preserve SSH key ciphers during sync so the `SSH Key` tab can show real data instead of always being empty because unsupported items were skipped.
- Keep existing row selection, detail presentation, and row actions working inside filtered result sets.

**Non-Goals:**
- Adding an `All` tab or redesigning the overall popover layout.
- Implementing create, edit, import, or full field-specific rendering for SSH key items.
- Expanding support to other Bitwarden cipher types beyond the requested `SSH Key` type.

## Decisions

### Introduce a dedicated vault tab model instead of reusing `CipherType`
The UI needs six filters, but only five of them map to item types and `Favorites` cuts across all types. A dedicated `VaultItemTab` model keeps presentation order and labels stable while letting the filtering code map tabs either to a `CipherType` or to the `favorite` flag.

Alternative considered: reuse `CipherType` plus a special-case favorites button. Rejected because it would split one filtering concept across multiple state variables and make the tab strip harder to keep consistent.

### Keep tab order as mutable view-model state and gate drag reordering behind the Command modifier
The tab strip now supports ad hoc reordering, so the client needs mutable ordered-tab state separate from the enum's canonical declaration order. Restricting drag reordering to the `Command` modifier preserves normal click-to-select behavior and avoids accidental reorders during ordinary pointer use in the narrow popover.

Alternative considered: always-on dragging or an explicit edit mode. Rejected because always-on dragging makes simple tab selection too fragile, while a separate edit mode adds more UI than the requested interaction needs.

### Apply tab filtering in the view model after the current search source is resolved
`VaultViewModel` already treats `allCiphers` as the source of truth and recomputes `visibleCiphers` when the search query changes. The least disruptive extension is to add the selected tab as another filter in the same recomputation path so empty state, count, sync refresh, and delete refresh all stay coherent.

Alternative considered: add separate fetch/search APIs per type. Rejected because current vault data is already loaded in memory for the popover and the requested behavior is presentational rather than persistence-driven.

### Default the vault to the `Login` tab and keep search scoped to the active tab
The requested tab list does not include `All`, so the implementation needs a stable initial filter. Defaulting to `Login` matches the first requested tab and the most common Bitwarden use case, while keeping search scoped to the active tab avoids surprising cross-tab results.

Alternative considered: synthesize an implicit all-items state. Rejected because it would introduce behavior that was not requested and would complicate the tab model and empty-state semantics.

### Add `SSH Key` as a supported cipher type without introducing a full SSH-key payload model yet
The current blocker is that `SyncService` skips unknown cipher types before the vault UI can filter them. Adding an `sshKey` enum case and extending type-based display helpers is enough to retain, persist, and filter SSH key items using generic cipher metadata such as name, notes, and favorite state.

Alternative considered: implement full SSH-key data modeling and detail rendering in the same change. Rejected because the request is about vault filtering and discovery, and a narrower first step reduces the blast radius across decryption, storage, and detail presentation.

## Risks / Trade-offs

- [Requested tabs omit an all-items view] → Default to `Login` and document that broader list restoration is out of scope for this change.
- [SSH key items may have sparse detail rendering at first] → Preserve sync and filtering now, and leave richer SSH-key field presentation to a follow-up change.
- [Six filters can be tight in a menu bar popover] → Use a compact, horizontally scrollable or compressible tab treatment instead of a wide fixed segmented control.
- [Drag reordering could conflict with normal tab switching] → Only enable drag behavior while the `Command` modifier is held and keep plain clicks as the default interaction.
- [Filtering regressions could desynchronize count, empty state, and visible rows] → Centralize tab-plus-search recomputation in `VaultViewModel` rather than scattering filter logic across the view tree.
- [Reordered tab order is not yet persisted across app restarts] → Treat the feature as view-local ordering for now and defer persistence until there is an explicit product requirement for saved tab order.

## Migration Plan

No database schema migration is required because ciphers are stored as encoded JSON blobs. Users gain SSH key visibility on the next successful vault sync after the app update.

## Open Questions

None.
