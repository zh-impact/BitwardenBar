import SwiftUI
import AppKit

// MARK: - CipherDetailView

/// Shows all fields for a cipher with one-tap copy for each field.
struct CipherDetailView: View {

    let cipher: Cipher
    let totpService: TOTPService

    @State private var showPassword = false
    @State private var totpCode: TOTPService.TOTPCode?
    @State private var totpTimer: Timer?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                CipherIcon(cipher: cipher).frame(width: 32, height: 32)
                VStack(alignment: .leading) {
                    Text(cipher.name).font(.headline).lineLimit(1)
                    Text(cipher.type.displayName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 2) {
                    switch cipher.type {
                    case .login: loginFields
                    case .card: cardFields
                    case .identity: identityFields
                    case .secureNote: secureNoteFields
                    case .sshKey: sshKeyFields
                    }

                    if let notes = cipher.notes, !notes.isEmpty {
                        FieldRow(label: "Notes", value: notes, monospace: false)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 300)
        .onAppear { startTOTP() }
        .onDisappear { totpTimer?.invalidate() }
    }

    // MARK: - Login Fields

    @ViewBuilder
    private var loginFields: some View {
        if let username = cipher.login?.username, !username.isEmpty {
            FieldRow(label: "Username", value: username)
        }
        if let password = cipher.login?.password, !password.isEmpty {
            PasswordFieldRow(password: password)
        }
        if let totp = cipher.login?.totp, !totp.isEmpty {
            TOTPFieldRow(code: totpCode)
        }
        if let uris = cipher.login?.uris {
            ForEach(Array(uris.enumerated()), id: \.offset) { _, uri in
                if let u = uri.uri, !u.isEmpty {
                    FieldRow(label: "URL", value: u)
                }
            }
        }
    }

    // MARK: - Card Fields

    @ViewBuilder
    private var cardFields: some View {
        if let name = cipher.card?.cardholderName, !name.isEmpty {
            FieldRow(label: "Cardholder", value: name)
        }
        if let number = cipher.card?.number, !number.isEmpty {
            FieldRow(label: "Number", value: number, monospace: true)
        }
        if let exp = formattedExpiry, !exp.isEmpty {
            FieldRow(label: "Expires", value: exp)
        }
        if let code = cipher.card?.code, !code.isEmpty {
            PasswordFieldRow(label: "CVV", password: code)
        }
    }

    private var formattedExpiry: String? {
        let m = cipher.card?.expMonth ?? ""
        let y = cipher.card?.expYear ?? ""
        if m.isEmpty && y.isEmpty { return nil }
        return "\(m)/\(y)"
    }

    // MARK: - Identity Fields

    @ViewBuilder
    private var identityFields: some View {
        let id = cipher.identity
        if let name = id?.fullName, !name.isEmpty { FieldRow(label: "Name", value: name) }
        if let email = id?.email, !email.isEmpty { FieldRow(label: "Email", value: email) }
        if let phone = id?.phone, !phone.isEmpty { FieldRow(label: "Phone", value: phone) }
        if let company = id?.company, !company.isEmpty { FieldRow(label: "Company", value: company) }
    }

    // MARK: - Secure Note

    @ViewBuilder
    private var secureNoteFields: some View {
        EmptyView()
    }

    // MARK: - SSH Key

    @ViewBuilder
    private var sshKeyFields: some View {
        EmptyView()
    }

    // MARK: - TOTP

    private func startTOTP() {
        guard let totp = cipher.login?.totp, !totp.isEmpty else { return }
        updateTOTP(totp: totp)
        totpTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateTOTP(totp: totp)
        }
    }

    private func updateTOTP(totp: String) {
        totpCode = totpService.generateCode(from: totp)
    }
}

// MARK: - FieldRow

struct FieldRow: View {
    let label: String
    let value: String
    var monospace = true

    @State private var copied = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(monospace ? .system(.callout, design: .monospaced) : .callout)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            Spacer()
            Button {
                copyValue()
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copied ? .green : .secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Copy")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func copyValue() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }
}

// MARK: - PasswordFieldRow

struct PasswordFieldRow: View {
    var label = "Password"
    let password: String
    @State private var visible = false
    @State private var copied = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(visible ? password : String(repeating: "•", count: min(password.count, 12)))
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
            }
            Spacer()
            Button {
                withAnimation { visible.toggle() }
            } label: {
                Image(systemName: visible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help(visible ? "Hide" : "Show")

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(password, forType: .string)
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copied ? .green : .secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Copy")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - TOTPFieldRow

struct TOTPFieldRow: View {
    let code: TOTPService.TOTPCode?
    @State private var copied = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TOTP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(code?.code ?? "------")
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .foregroundStyle(timerColor)

                    if let code {
                        // Countdown ring
                        Circle()
                            .trim(from: 0, to: CGFloat(code.timeRemaining) / CGFloat(code.period))
                            .stroke(timerColor, lineWidth: 2)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 16, height: 16)
                            .animation(.linear(duration: 1), value: code.timeRemaining)

                        Text("\(code.timeRemaining)s")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                guard let codeStr = code?.code else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(codeStr, forType: .string)
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copied ? .green : .secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var timerColor: Color {
        guard let remaining = code?.timeRemaining else { return .primary }
        return remaining <= 5 ? .red : remaining <= 10 ? .orange : .primary
    }
}

// MARK: - CipherType display

extension CipherType {
    var displayName: String {
        switch self {
        case .login: return "Login"
        case .secureNote: return "Secure Note"
        case .card: return "Card"
        case .identity: return "Identity"
        case .sshKey: return "SSH Key"
        }
    }
}
