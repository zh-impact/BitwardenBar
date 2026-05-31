## 1. Artifact Backfill

- [ ] 1.1 Review the implemented auth, unlock, and vault interaction changes against this proposal for completeness
- [ ] 1.2 Confirm the new capability split (`desktop-auth-session`, `desktop-vault-detail-presentation`) matches the actual code ownership boundaries

## 2. Spec Validation

- [ ] 2.1 Validate the `desktop-auth-session` scenarios against the implemented flows in `AuthService`, `APIService`, and `LoginView`
- [ ] 2.2 Validate the `desktop-vault-detail-presentation` scenarios against the implemented flows in `CipherListView`, `VaultRootView`, and related UI state

## 3. Follow-up Documentation Decisions

- [ ] 3.1 Decide whether biometric unlock completion needs a separate capability or a follow-up change
- [ ] 3.2 Decide whether menu bar shell lifecycle constraints should stay under vault-detail presentation or move into a separate desktop-shell capability