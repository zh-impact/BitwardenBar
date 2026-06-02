## ADDED Requirements

### Requirement: Desktop auth flows SHALL open in dedicated windows instead of the menu bar popover
When the desktop app requires login or vault unlock, it SHALL present that flow in a dedicated standalone window and SHALL NOT keep the auth UI inside the transient menu bar popover.

#### Scenario: User must log in before accessing the vault
- **WHEN** the user opens the app while no authenticated vault session is available
- **THEN** the app SHALL close or avoid opening the menu bar popover and SHALL present the login flow in a dedicated window that remains available until the user completes or explicitly cancels login

#### Scenario: User must unlock an existing locked session
- **WHEN** the user opens the app while the account is locked but a logged-in session can be unlocked
- **THEN** the app SHALL present the unlock flow in a dedicated window instead of the popover and SHALL keep that window available until unlock succeeds or the user explicitly cancels

### Requirement: Desktop settings SHALL be managed in a standalone settings window
The desktop app SHALL present settings in a dedicated window that is independent from popover lifetime so configuration work is not dismissed by transient popover behavior.

#### Scenario: User opens settings from vault browsing
- **WHEN** the user invokes Settings while viewing vault content from the menu bar UI
- **THEN** the app SHALL present a standalone settings window and the settings surface SHALL NOT depend on the popover remaining open

#### Scenario: User interacts outside the menu bar UI while settings is open
- **WHEN** the settings window is open and the user clicks elsewhere or otherwise dismisses the popover
- **THEN** the settings window SHALL remain open until the user explicitly closes it or completes the settings interaction

### Requirement: Desktop window presentation SHALL coordinate activation policy and single-window reuse
The desktop app SHALL promote itself to a regular foreground app while any login, unlock, or settings window is open, restore accessory-only behavior after all standalone windows close, and reuse an existing window of the same flow type instead of opening duplicates.

#### Scenario: Standalone flow window becomes active
- **WHEN** the app opens a login, unlock, or settings window
- **THEN** the app SHALL become a regular active app for the duration of that standalone window and the requested window SHALL become the active key window

#### Scenario: User requests a flow that is already open
- **WHEN** the app receives a request to open a login, unlock, or settings flow whose standalone window already exists
- **THEN** the app SHALL bring the existing window forward instead of opening a duplicate window

#### Scenario: Last standalone window closes
- **WHEN** the final open login, unlock, or settings window closes and no other standalone window remains
- **THEN** the app SHALL return to its accessory menu bar behavior
