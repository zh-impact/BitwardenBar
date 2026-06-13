## 1. Vault Row Action Surface

- [x] 1.1 Add a row-action model or helper that derives launch availability, copyable username/password values, and more-actions availability from a `Cipher`
- [x] 1.2 Update the vault list row UI to render explicit trailing controls for launch, copy, and more-actions while preserving row tap to open item details
- [x] 1.3 Wire the copy menu and more-actions menu so they only show supported actions for the current item and copy selected values to the macOS pasteboard

## 2. Launch Behavior

- [x] 2.1 Implement Bitwarden-compatible login URI launchability and launch URI normalization for scheme-less website values
- [x] 2.2 Add a macOS browser-launch path for login items that uses the derived launch URI and keeps unsupported or unsafe URIs hidden
- [x] 2.3 Decide whether launch should update local usage metadata now or remain stateless, and document the chosen behavior in code or follow-up notes

## 3. Soft Delete Flow

- [x] 3.1 Add the API request and service-layer support needed to soft-delete a cipher on the server
- [x] 3.2 Route row delete actions through `VaultViewModel` so successful soft deletes update local cache state and refresh the filtered visible list
- [x] 3.3 Add failure handling for delete so an unsuccessful mutation leaves the item visible and surfaces an actionable error state to the vault UI

## 4. Validation

- [x] 4.1 Add or update focused tests for launchability rules, row action availability, and soft-delete list refresh behavior where the current test surface allows
- [x] 4.2 Run `swift build` from `BitwardenBar/` to verify the changed vault UI, network, and service code compiles cleanly
- [x] 4.3 Run `swift test` from `BitwardenBar/` or the narrowest relevant test target available to validate the new vault item action behavior
