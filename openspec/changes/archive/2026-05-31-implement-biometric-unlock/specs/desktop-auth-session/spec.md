## ADDED Requirements

### Requirement: Desktop biometric unlock SHALL restore a locked vault session
The desktop client SHALL allow a previously logged-in account to unlock a locked vault with device biometrics when device biometrics are available and the account has stored local vault key material that can restore the local crypto session.

#### Scenario: Biometric unlock succeeds with stored local material
- **WHEN** the account is locked, the device successfully completes biometric authentication, and the account has either the dedicated biometric-protected local key or the generic locally stored fallback key
- **THEN** the client SHALL restore the local vault session without requiring the master password again

#### Scenario: Biometric unlock falls back when local material is unavailable
- **WHEN** the user attempts biometric unlock but neither the dedicated biometric-protected key nor the generic local fallback key is readable
- **THEN** the client SHALL keep the account locked, require master-password unlock as the fallback path, and SHALL NOT report the account as unlocked

### Requirement: Locked-state unlock UI SHALL advertise biometric unlock only when available
The desktop client SHALL present the biometric unlock action only when the device can perform biometric authentication and the account has the stored local material needed to complete biometric unlock.

#### Scenario: Biometric unlock action is available
- **WHEN** the locked-state UI is shown for an account on a device with available biometrics and the account has either the dedicated biometric-protected key or the generic local fallback key
- **THEN** the client SHALL present the biometric unlock action alongside the master-password fallback

#### Scenario: Biometric unlock action is hidden when prerequisites are missing
- **WHEN** the locked-state UI is shown but biometrics are unavailable or the account lacks both the dedicated biometric-protected key and the generic local fallback key
- **THEN** the client SHALL omit the biometric unlock action and continue offering master-password unlock

### Requirement: Desktop master-password unlock SHALL recover from stale local encrypted key material
The desktop client SHALL retry master-password unlock with freshly fetched encrypted key material when local encrypted unlock material produces a crypto unlock failure.

#### Scenario: Local encrypted key material is stale or mismatched
- **WHEN** a master-password unlock attempt fails with a crypto unlock error while an authenticated session is still available
- **THEN** the client SHALL fetch fresh encrypted key material from the authenticated profile endpoint, retry the master-password unlock once with that refreshed material, and only then surface the failure if unlock still cannot complete
