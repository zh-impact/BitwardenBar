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
After a successful login, the desktop client SHALL persist the encrypted user key and encrypted private key needed for later password-based unlock, and it SHALL attempt recovery when that local state is missing or stale.

#### Scenario: Successful login seeds later password unlock
- **WHEN** a login completes with encrypted key material available from the token or profile response
- **THEN** the client SHALL persist that encrypted key material and use it during later locked-state master-password unlock attempts

#### Scenario: Local encrypted key material is missing or stale
- **WHEN** a master-password unlock attempt cannot proceed because local encrypted key material is missing, or local unlock fails HMAC verification
- **THEN** the client SHALL request the authenticated profile, refresh the encrypted key material from the server, persist it, and retry the unlock before requiring a fresh full login

### Requirement: Auth requests SHALL preserve the verified Bitwarden protocol shape
The desktop client SHALL preserve the protocol details already required for Bitwarden identity compatibility.

#### Scenario: Token request uses verified identity-server shape
- **WHEN** the client submits `/connect/token`
- **THEN** it SHALL use the identity server, send `application/x-www-form-urlencoded`, include `Auth-Email`, send `Device-Type: 7` and `Accept: application/json`, and omit `Bitwarden-Client-Name` and `Bitwarden-Client-Version` from the token request itself

#### Scenario: Other authenticated requests use platform-identification headers
- **WHEN** the client submits authenticated identity or API requests after session establishment
- **THEN** it SHALL send the desktop platform headers required by the verified protocol contract
