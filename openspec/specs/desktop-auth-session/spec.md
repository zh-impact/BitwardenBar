## Purpose

Define the required desktop authentication, session establishment, and password-unlock behavior for BitwardenBar's Bitwarden integration.

## Requirements

### Requirement: Desktop password login SHALL support Bitwarden's two-step authentication flow
The desktop client SHALL complete password login using the sequence prelogin, token exchange, optional two-factor continuation, authenticated profile fetch, vault unlock, and initial sync.

#### Scenario: Server requires two-factor authentication
- **WHEN** the token endpoint responds with a two-factor-required error and available providers
- **THEN** the client SHALL keep the entered email and password, surface the available second-factor flow, and submit a follow-up token request using the selected provider and entered verification token

#### Scenario: Two-factor completion requires authenticated follow-up requests
- **WHEN** the client receives a successful token response before an active account is fully persisted
- **THEN** the client SHALL be able to fetch the authenticated profile using the fresh access token without depending on prior active-account state

### Requirement: Desktop auth decoding SHALL accept Bitwarden's mixed-case response contracts
The desktop client SHALL decode Bitwarden auth and profile responses when those payloads mix snake_case OAuth keys with PascalCase account and crypto keys.

#### Scenario: Identity token response mixes casing styles
- **WHEN** `/connect/token` returns OAuth fields such as `access_token` together with crypto fields such as `Key`, `PrivateKey`, or `KdfIterations`
- **THEN** the client SHALL decode all required fields into the auth session model without treating the response as malformed

#### Scenario: Profile response uses PascalCase account fields
- **WHEN** `/accounts/profile` returns fields such as `Id`, `Email`, `Name`, `Key`, and `PrivateKey`
- **THEN** the client SHALL decode the profile successfully and use it for account identity and encrypted key-material recovery

### Requirement: Master-password unlock SHALL recover from stale local encrypted key material
After a successful login, the desktop client SHALL persist the encrypted user key and encrypted private key needed for later password-based unlock, and it SHALL retry master-password unlock with freshly fetched encrypted key material when local encrypted unlock material produces a crypto unlock failure.

#### Scenario: Successful login seeds later password unlock
- **WHEN** a login completes with encrypted key material available from the token or profile response
- **THEN** the client SHALL persist that encrypted key material and use it during later locked-state master-password unlock attempts

#### Scenario: Local encrypted key material is missing or stale
- **WHEN** a master-password unlock attempt fails with a crypto unlock error while an authenticated session is still available
- **THEN** the client SHALL fetch fresh encrypted key material from the authenticated profile endpoint, retry the master-password unlock once with that refreshed material, and only then surface the failure if unlock still cannot complete

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

### Requirement: Auth requests SHALL preserve the verified Bitwarden protocol shape
The desktop client SHALL preserve the protocol details already required for Bitwarden identity compatibility.

#### Scenario: Token request uses verified identity-server shape
- **WHEN** the client submits `/connect/token`
- **THEN** it SHALL use the identity server, send `application/x-www-form-urlencoded`, include `Auth-Email`, send `Device-Type: 7` and `Accept: application/json`, and omit `Bitwarden-Client-Name` and `Bitwarden-Client-Version` from the token request itself

#### Scenario: Other authenticated requests use platform-identification headers
- **WHEN** the client submits authenticated identity or API requests after session establishment
- **THEN** it SHALL send the desktop platform headers required by the verified protocol contract
