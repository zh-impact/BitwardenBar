## Purpose

Define the required top-level vault item-type tab behavior for BitwardenBar's menu bar vault popover, including tab-scoped filtering, search interaction, and retained SSH key visibility.

## Requirements

### Requirement: Vault UI SHALL expose top-level item-type tabs in the popover
The vault popover SHALL show a top-level tab strip above the item list with tabs for `Login`, `Note`, `Card`, `Identity`, `SSH Key`, and `Favorites`, and it SHALL use the active tab to determine which vault items are visible.

#### Scenario: Vault opens with the default tab selected
- **WHEN** the user opens the unlocked vault popover
- **THEN** the client SHALL render the tabs in the order `Login`, `Note`, `Card`, `Identity`, `SSH Key`, `Favorites`
- **AND** the `Login` tab SHALL be selected by default
- **AND** the visible list SHALL include only login items

#### Scenario: User switches to a type-specific tab
- **WHEN** the user selects the `Note`, `Card`, `Identity`, or `SSH Key` tab
- **THEN** the client SHALL show only items whose cipher type matches the selected tab
- **AND** the footer item count SHALL reflect only the visible items for that tab

#### Scenario: User switches to the favorites tab
- **WHEN** the user selects the `Favorites` tab
- **THEN** the client SHALL show only vault items whose favorite flag is true
- **AND** the favorites filter SHALL include matching items across every supported cipher type

#### Scenario: User reorders tabs with the Command modifier
- **WHEN** the user holds `Command` and drags one vault tab onto another tab in the strip
- **THEN** the client SHALL reorder the tab strip to reflect the drop position
- **AND** the reordered sequence SHALL be used for subsequent rendering in the current vault view

#### Scenario: User drags without the Command modifier
- **WHEN** the user drags on a vault tab without holding `Command`
- **THEN** the client SHALL keep normal tab-selection behavior
- **AND** it SHALL not reorder the tab strip

### Requirement: Vault search SHALL remain scoped to the active tab
The vault search field SHALL continue to filter visible items, but it SHALL apply only within the currently selected top-level tab.

#### Scenario: User searches within the default login tab
- **WHEN** the `Login` tab is active and the user enters a search query
- **THEN** the client SHALL show only login items that match the query
- **AND** it SHALL not show matching items from other tabs

#### Scenario: User changes tabs while a search query is active
- **WHEN** the user switches tabs with a non-empty search query
- **THEN** the client SHALL immediately recompute the visible list using both the selected tab and the current query
- **AND** the empty state message and footer item count SHALL reflect that combined filter

### Requirement: SSH key ciphers SHALL be retained for vault filtering
The client SHALL preserve synced SSH key ciphers so the `SSH Key` and `Favorites` tabs can surface them instead of losing them as unsupported types.

#### Scenario: Sync returns SSH key ciphers
- **WHEN** a vault sync response includes one or more SSH key ciphers
- **THEN** the client SHALL retain those ciphers in local vault state
- **AND** the `SSH Key` tab SHALL make them visible in the vault list

#### Scenario: Favorite SSH key appears in favorites
- **WHEN** a synced SSH key cipher is marked as a favorite
- **THEN** the client SHALL include it in the `Favorites` tab results

### Requirement: Tab filtering SHALL preserve existing vault row interactions
Filtering the vault list by top-level tab SHALL not change the existing behavior for selecting a row or using supported row actions on visible items.

#### Scenario: User opens details from a filtered result
- **WHEN** the user selects a visible row while any top-level tab filter is active
- **THEN** the client SHALL open that item's detail presentation

#### Scenario: User uses row actions from a filtered result
- **WHEN** the user invokes a supported row action on a visible item while a top-level tab filter is active
- **THEN** the client SHALL perform that action against the same filtered-list item without clearing the active tab
