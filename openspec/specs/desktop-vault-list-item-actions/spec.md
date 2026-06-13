## Purpose

Define the required row-level quick actions and overflow actions for BitwardenBar's vault list items.

## Requirements

### Requirement: Vault list items SHALL expose row-level quick actions without replacing row selection
The vault list SHALL keep row selection available for opening item details while also exposing explicit trailing action controls for supported vault items.

#### Scenario: User taps a row outside the action controls
- **WHEN** the user activates a vault list row outside its trailing action controls
- **THEN** the client SHALL open that item's detail presentation

#### Scenario: Login item with a launchable URI is rendered
- **WHEN** the client renders a login item that has at least one launchable URI
- **THEN** the row SHALL show a launch action control in its trailing action area

#### Scenario: Item without a launchable URI is rendered
- **WHEN** the client renders a non-login item or a login item whose URIs are absent or not launchable
- **THEN** the row SHALL omit the launch action control

### Requirement: Vault list items SHALL provide item-aware credential copy actions
The vault list SHALL expose a dedicated copy action entry point that expands to only the credential copy operations supported by the current item.

#### Scenario: Login item has username and password
- **WHEN** the user opens the row's copy action for a login item that has both a username and a password
- **THEN** the client SHALL show separate actions for copying the username and copying the password

#### Scenario: Login item is missing one credential value
- **WHEN** the user opens the row's copy action for a login item that is missing either username or password
- **THEN** the client SHALL omit the unavailable copy action and keep the available one

#### Scenario: User chooses a copy action
- **WHEN** the user chooses a supported copy action from the row's copy menu
- **THEN** the client SHALL copy the selected value to the macOS pasteboard

### Requirement: Vault list items SHALL provide a constrained more-actions menu
The vault list SHALL expose a more-actions menu whose initial implementation is limited to launch, copy username, copy password, and delete, with each action shown only when it is supported by the current item.

#### Scenario: Login item supports all requested actions
- **WHEN** the user opens the more-actions menu for a login item with a launchable URI, username, and password
- **THEN** the menu SHALL include launch, copy username, copy password, and delete actions

#### Scenario: Launch is unavailable for the current item
- **WHEN** the user opens the more-actions menu for an item that does not have a launchable URI
- **THEN** the menu SHALL omit the launch action

#### Scenario: Copy values are unavailable for the current item
- **WHEN** the user opens the more-actions menu for an item that lacks username or password values
- **THEN** the menu SHALL omit each unsupported copy action individually

### Requirement: Launch actions SHALL use Bitwarden-compatible launch URI behavior
Launch actions in the vault list SHALL only open URIs that are valid launch targets for Bitwarden login items, and SHALL normalize scheme-less website values into a browser-launch URI.

#### Scenario: Login item has a scheme-less website value
- **WHEN** a login item has a website value that is launchable but does not include a URI scheme
- **THEN** the client SHALL launch that value in the browser using an `http://`-prefixed launch URI

#### Scenario: Login item URI is regex-based or unsafe
- **WHEN** a login item URI is regex-based or otherwise not safe to launch
- **THEN** the client SHALL treat the URI as not launchable and SHALL not expose a launch action for it

### Requirement: Delete from the vault list SHALL soft-delete the item and remove it from the visible list
The vault list's delete action SHALL use Bitwarden-style soft-delete behavior rather than permanent deletion.

#### Scenario: User deletes an item from the more-actions menu
- **WHEN** the user invokes delete for a visible vault item and the server-side soft-delete succeeds
- **THEN** the client SHALL mark the item deleted in local state and SHALL remove it from the visible vault list

#### Scenario: Soft-delete fails
- **WHEN** the user invokes delete for a visible vault item and the soft-delete operation fails
- **THEN** the client SHALL leave the item visible in the vault list
