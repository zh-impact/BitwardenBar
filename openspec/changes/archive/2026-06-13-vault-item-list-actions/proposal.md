## Why

BitwardenBar's vault list currently exposes only a partial context menu and does not provide the row-level quick actions shown in the target interaction design. Defining these behaviors now reduces the risk of inconsistent login-item actions, missing browser launch behavior, and ad hoc row controls as the vault UI continues to evolve.

## What Changes

- Add row-level vault item action behavior for login items, including opening an existing link in the browser from the list entry.
- Add a dedicated copy action entry point on each row that expands to item-aware copy options such as username and password.
- Add a more-actions entry point on each row that currently includes launch, copy username, copy password, and delete where the underlying item supports those operations.
- Preserve existing detail-sheet behavior while extending list-item interactions so list actions and detail presentation remain distinct user flows.

## Capabilities

### New Capabilities
- `desktop-vault-list-item-actions`: Row-level quick actions and overflow actions for vault list items, including browser launch and credential copy behavior for login items.

### Modified Capabilities
- None.

## Impact

- Affected code: `BitwardenBar/Sources/BitwardenBar/UI/Vault`, supporting vault item action handling, pasteboard integration, browser launch integration, and delete flow wiring.
- Affected systems: SwiftUI menu bar list interactions, macOS browser opening behavior, clipboard operations, and vault item mutation flows.
- Reference inputs: `references/clients/` and `references/server/` may be consulted to align launch, copy, and delete action semantics with Bitwarden behavior.
