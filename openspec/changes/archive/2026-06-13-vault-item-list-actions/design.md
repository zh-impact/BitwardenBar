## Context

The current vault list uses row tap for detail presentation and a limited right-click context menu for a few copy actions. It does not expose the explicit row-level controls shown in the target interaction, does not have a browser-launch path for login items, and does not yet have any cipher mutation path for delete.

This change touches both presentation and behavior boundaries. The UI lives in `UI/Vault`, but `Delete` needs a real mutation flow through the network layer and local cache, and `Launch` needs URL safety rules that match Bitwarden's existing clients instead of ad hoc `URL(string:)` behavior.

## Goals / Non-Goals

**Goals:**
- Add row-level controls for login launch, copy actions, and overflow actions without regressing the existing row tap -> detail sheet behavior.
- Keep action availability data-driven so only supported login actions appear for a given item.
- Match Bitwarden's launchability semantics for login URIs, including support for host-like values without a scheme and rejection of non-launchable or regex-only URIs.
- Implement delete as a real vault mutation that updates server state and removes the item from the local list state after success.

**Non-Goals:**
- Rebuild the full browser-extension vault row feature set such as favorite, edit, clone, archive, or collection assignment.
- Introduce a broad reusable menu framework outside the vault list.
- Add permanent delete or trash management UI.
- Change the existing detail sheet into the primary place for these new list actions.

## Decisions

### 1. Row actions stay visually on the list row, while detail presentation stays selection-driven

The list row will gain explicit trailing controls: a launch button when the item can launch, a copy `Menu` for credential copy actions, and a more-actions `Menu` for launch/copy/delete. Row tap will continue to select the cipher and open the detail sheet from list-owned state.

This keeps the new interaction model aligned with the target design without reintroducing the row-lifecycle problem already documented in `desktop-vault-detail-presentation`. The row owns ephemeral menu state; the list container continues to own navigation/presentation state.

Rejected alternatives:
- Keep everything in `contextMenu`: rejected because it is less discoverable and does not match the requested interaction model.
- Move these actions into the detail sheet only: rejected because the requested behavior is list-first and optimized for quick access.

### 2. Launch availability follows Bitwarden launch URI semantics, not raw URL parsing

Launch will be available only for login items that have at least one launchable URI. The implementation should mirror Bitwarden's `canLaunch` / `launchUri` behavior:
- regex-match URIs are not launchable;
- host-like values without a scheme are normalized to a browser-launch URI by prepending `http://`;
- launch is blocked for values that fail safe-launch checks.

This decision matches the reference client behavior and avoids two bad outcomes: showing a launch button for unusable values, or attempting to open malformed/surprising URLs directly through AppKit.

Rejected alternatives:
- Show launch for any non-empty first URI: rejected because it would allow regex URIs and malformed strings.
- Auto-prepend `https://`: rejected because the reference clients normalize scheme-less website values to `http://`, not a custom app-specific rule.

### 3. Delete means soft delete, routed through view model -> service -> API -> local cache

The overflow menu's `Delete` action will use Bitwarden's soft-delete semantics rather than permanent deletion. The local code already models deleted items through `deletedDate` and filters them out in `CipherService.fetchAll`, so soft delete fits the existing cache model and aligns with Bitwarden's trash behavior.

Implementation should add a dedicated mutation path that starts in the vault view model, calls a new cipher mutation service method, performs the server request, persists the resulting deleted state locally, and then refreshes visible list data on the main actor. The row itself should not perform destructive mutations directly.

This keeps destructive state changes out of transient row views and gives the list a single place to handle optimistic updates, error presentation, and post-delete refresh.

Rejected alternatives:
- Hard delete via `DELETE /ciphers/{id}`: rejected because the user-facing `Delete` action in Bitwarden commonly maps to trash/soft-delete semantics and the local model is already shaped around `deletedDate`.
- Local-only removal without a server mutation: rejected because the next sync would restore the item and create inconsistent behavior.

### 4. Shared row-action helpers should centralize clipboard, launch, and availability rules

Copy and launch rules should be described once in a small vault-row action helper or view-model adapter rather than duplicated across button handlers and context menus. The row view can render from a compact action surface such as `canLaunch`, `copyableUsername`, `copyablePassword`, and `deleteAvailable`, while the actual side effects remain delegated to higher-level handlers.

This keeps the row rendering simple, reduces divergence between the copy menu and more-actions menu, and makes it easier to extend later with favorite/edit/archive without rewriting per-button logic.

Rejected alternatives:
- Inline all action rules in the SwiftUI row body: rejected because the row will become harder to read and easier to desynchronize across menus.

## Risks / Trade-offs

- [Menu-heavy rows can interfere with row selection or hover hit testing] -> Keep buttons in the trailing action area only, preserve a clear row content shape, and avoid attaching selection to the action controls themselves.
- [Soft delete requires new network and local-store behavior that does not exist today] -> Introduce the mutation path end to end and validate it with a focused build/test pass before broader UI polish.
- [Unsafe or malformed URIs could produce surprising browser launches] -> Reuse Bitwarden-style launchability checks and normalize only the specific scheme-less website case.
- [Post-delete list state could drift from visible search/filter state] -> Route deletion through `VaultViewModel` so the same refresh/filter pipeline is reused after a successful mutation.

## Migration Plan

No persistent data migration is required. The rollout is additive: add row actions, add launch helpers, add soft-delete API/service support, and refresh the visible vault list after successful delete.

Rollback is straightforward: remove the row action UI and stop invoking the mutation path. Soft-deleted items remain consistent with Bitwarden server state and will continue to sync according to existing vault sync behavior.

## Open Questions

- Whether the first implementation should expose a confirmation prompt before soft delete, or defer that to a later UX pass.
- Whether launch activity should also record a local `lastLaunched` timestamp as Bitwarden clients do, or remain stateless for now.
