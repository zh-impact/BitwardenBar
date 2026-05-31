import SwiftUI
import Carbon

// MARK: - SettingsView

struct SettingsView: View {

    let account: Account
    let services: ServiceContainer
    let appState: AppState

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hotkey.keyCode") private var hotKeyCode: Int = Int(kVK_ANSI_B)
    @AppStorage("hotkey.modifiers") private var hotKeyModifiers: Int = 786432 // cmd+shift
    @AppStorage("vault.autoLockMinutes") private var autoLockMinutes: Int = 15
    @AppStorage("vault.clearClipboardSeconds") private var clearClipboardSeconds: Int = 30

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            Form {
                // Accounts section
                Section("Accounts") {
                    AccountsListView(services: services, appState: appState)
                }

                // Security
                Section("Security") {
                    Picker("Auto-lock after", selection: $autoLockMinutes) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("Never").tag(0)
                    }

                    Picker("Clear clipboard after", selection: $clearClipboardSeconds) {
                        Text("10 seconds").tag(10)
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("Never").tag(0)
                    }
                }

                // Hotkey
                Section("Global Shortcut") {
                    HStack {
                        Text("Show/Hide vault")
                        Spacer()
                        HotKeyRecorderView(
                            keyCode: $hotKeyCode,
                            modifiers: $hotKeyModifiers
                        )
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("BitwardenBar")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    Link("View on GitHub", destination: URL(string: "https://github.com/")!)
                        .font(.callout)
                }
            }
            .formStyle(.grouped)
            .frame(height: 380)
        }
        .frame(width: 380)
    }
}

// MARK: - AccountsListView

struct AccountsListView: View {

    let services: ServiceContainer
    let appState: AppState

    var body: some View {
        let accounts = services.accountStore.accounts
        ForEach(accounts) { account in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .font(.callout)
                    Text(account.identityURL?.host ?? "bitwarden.com")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if services.accountStore.activeAccountId == account.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Switch") {
                        services.accountStore.setActive(id: account.id)
                        appState.refresh()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                Button(role: .destructive) {
                    services.authService.logout(userId: account.id)
                    appState.didLogout()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Log out")
            }
        }
    }
}

// MARK: - HotKeyRecorderView

/// Simple keyboard shortcut display / record button.
struct HotKeyRecorderView: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    @State private var isRecording = false

    var body: some View {
        Button {
            isRecording = true
        } label: {
            Text(isRecording ? "Press shortcut…" : currentShortcutLabel)
                .font(.system(.callout, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isRecording ? Color.accentColor : Color(.separatorColor), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .background(
            KeyEventCapture(isActive: $isRecording, keyCode: $keyCode, modifiers: $modifiers)
        )
    }

    private var currentShortcutLabel: String {
        var parts = [String]()
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        // Map keyCode to string (simplified)
        let keyName = keyCodeToString(keyCode) ?? "?"
        parts.append(keyName.uppercased())
        return parts.joined()
    }

    private func keyCodeToString(_ code: Int) -> String? {
        let map: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C",
            9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N",
            46: "M", 18: "1", 19: "2", 20: "3", 21: "4", 22: "5", 23: "6",
            24: "7", 25: "8", 26: "9", 29: "0"
        ]
        return map[code]
    }
}

// MARK: - KeyEventCapture (NSViewRepresentable)

private struct KeyEventCapture: NSViewRepresentable {
    @Binding var isActive: Bool
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureNSView()
        view.onCapture = { code, mods in
            keyCode = code
            modifiers = mods
            isActive = false
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        (view as? KeyCaptureNSView)?.isCapturing = isActive
    }
}

private final class KeyCaptureNSView: NSView {
    var onCapture: ((Int, Int) -> Void)?
    var isCapturing = false

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isCapturing else { super.keyDown(with: event); return }
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !mods.isEmpty else { return }
        onCapture?(Int(event.keyCode), Int(mods.rawValue))
    }
}
