## Purpose

Define the required desktop global shortcut loading, persistence, and recording behavior for BitwardenBar.

## Requirements

### Requirement: Desktop global shortcut SHALL load from persisted settings with a safe default fallback
The desktop app SHALL register the global shortcut used to show or hide the vault from persisted shortcut settings when valid saved values exist, and it SHALL fall back to the default shortcut of Command-Shift-B when saved values are missing or invalid.

#### Scenario: Persisted shortcut is available at startup
- **WHEN** the app launches with a valid saved key code and modifier set for the global shortcut
- **THEN** the app SHALL register and listen for that saved shortcut instead of the built-in default

#### Scenario: Persisted shortcut is missing or invalid
- **WHEN** the app launches without saved shortcut values or with values that do not describe a valid modified key shortcut
- **THEN** the app SHALL register the default Command-Shift-B shortcut and keep the shortcut feature available

### Requirement: Desktop global shortcut changes SHALL take effect without relaunch
When the user records a new valid global shortcut in Settings, the desktop app SHALL persist the new shortcut and update the active global shortcut registration without requiring an app restart.

#### Scenario: User saves a new shortcut in Settings
- **WHEN** the user records a valid modified key shortcut in the settings recorder
- **THEN** the app SHALL persist the new shortcut and the new shortcut SHALL activate the vault toggle behavior in the current app session

### Requirement: Desktop shortcut recording SHALL capture only valid modified key shortcuts
The settings shortcut recorder SHALL capture a shortcut only after it receives a non-modifier key combined with at least one supported modifier, and it SHALL leave the previously saved shortcut unchanged when capture input is invalid.

#### Scenario: Recorder captures a valid shortcut
- **WHEN** the recorder is active and the user presses a non-modifier key with one or more of Command, Shift, Option, or Control
- **THEN** the recorder SHALL save that key-plus-modifier combination and exit recording mode

#### Scenario: Recorder receives invalid input
- **WHEN** the recorder is active and the user presses a key event without any supported modifiers or otherwise does not provide a valid shortcut combination
- **THEN** the recorder SHALL NOT overwrite the saved shortcut and SHALL remain ready for a valid shortcut capture or cancellation
