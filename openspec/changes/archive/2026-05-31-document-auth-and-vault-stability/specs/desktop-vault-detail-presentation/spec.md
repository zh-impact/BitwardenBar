## ADDED Requirements

### Requirement: Vault item details SHALL open from stable list-level selection state
The vault list SHALL present item details using state owned by the list container rather than transient state owned by lazily recycled row views.

#### Scenario: User selects a vault row
- **WHEN** the user clicks a vault list item
- **THEN** the client SHALL open that item's detail presentation from a stable selection owned above the individual row view

#### Scenario: Detail presentation survives row lifecycle churn
- **WHEN** the list re-renders, scrolls, or recycles row views while a detail presentation is active
- **THEN** the client SHALL keep the detail presentation valid without dereferencing deallocated row-owned state

### Requirement: Vault UI state transitions SHALL remain main-actor safe during auth and sync flows
UI-facing state that drives login, unlock, and post-login sync behavior SHALL be updated on the main actor.

#### Scenario: Two-factor completion triggers loading and sync updates
- **WHEN** login or two-factor completion starts background work that changes loading, error, or sync presentation state
- **THEN** the client SHALL apply those UI-facing state changes on the main actor

#### Scenario: Unlock and vault sync update list presentation
- **WHEN** master-password unlock or vault sync updates visible vault state
- **THEN** the client SHALL update the view model and presentation state without background-thread mutations of SwiftUI-bound properties