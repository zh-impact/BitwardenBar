## 1. Keychain Support

- [x] 1.1 Add dedicated `KeychainRepository` APIs for saving, reading, and deleting a biometric-protected decrypted user key per account
- [x] 1.2 Keep the existing password-unlock encrypted key material storage intact while isolating biometric-only storage semantics from the generic Keychain helpers
- [x] 1.3 Clear biometric-protected local unlock material during logout and other account-removal paths without deleting it on lock

## 2. Auth And Unlock Flow

- [x] 2.1 Seed the biometric-protected decrypted user key when login completes with the local material needed for later biometric unlock
- [x] 2.2 Replace the `unlockWithBiometrics` placeholder in `AuthService` with the full LocalAuthentication plus local session-restore flow
- [x] 2.3 Handle missing or invalidated biometric material by keeping the vault locked and falling back cleanly to master-password unlock

## 3. Locked-State UI

- [x] 3.1 Update `UnlockView` availability checks so the biometric action is shown only when device biometrics and required stored material are both available
- [x] 3.2 Keep the master-password path available and surface biometric failures without reporting the account as unlocked

## 4. Validation

- [x] 4.1 Add or update focused tests for biometric keychain handling and biometric unlock state restoration where the current test surface allows it
- [x] 4.2 Run `swift build` and any narrow auth-related tests needed to verify the biometric unlock implementation
