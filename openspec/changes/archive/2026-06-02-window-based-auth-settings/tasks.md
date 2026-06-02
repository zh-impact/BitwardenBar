## 1. Window Coordination Foundation

- [x] 1.1 Add an app-level window coordinator that owns presentation for the popover, login window, unlock window, and settings window.
- [x] 1.2 Implement single-window reuse for each flow type so repeated open requests focus the existing window instead of creating duplicates.

## 2. Move Auth And Settings Out Of The Popover

- [x] 2.1 Update login and unlock presentation so auth-required states open dedicated windows and do not keep auth UI inside the menu bar popover.
- [x] 2.2 Update vault/settings presentation so Settings opens in a standalone window instead of a sheet hosted by popover content.

## 3. Lifecycle And Activation Policy

- [x] 3.1 Close or avoid opening the popover when a login, unlock, or settings window is presented, and route completion or cancellation back through the coordinator.
- [x] 3.2 Tie application activation policy transitions to standalone window lifecycle so the app becomes `.regular` while auth/settings windows are open and returns to `.accessory` after the last one closes.

## 4. Validation

- [x] 4.1 Add or update focused tests for window reuse, auth/settings presentation routing, or coordinator-owned lifecycle behavior where the current test surface allows it.
- [x] 4.2 Run `swift build` and any targeted tests needed to confirm the new window presentation flow compiles and the app shell behavior remains stable.
