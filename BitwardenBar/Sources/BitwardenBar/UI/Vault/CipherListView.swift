import SwiftUI
import AppKit

// MARK: - CipherListView

struct CipherListView: View {

    let ciphers: [Cipher]
    let totpService: TOTPService
    let onDelete: (Cipher) -> Void

    @State private var selectedCipher: Cipher?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(ciphers) { cipher in
                    CipherRowView(
                        cipher: cipher,
                        totpService: totpService,
                        onDelete: { onDelete(cipher) },
                        onSelect: { selectedCipher = cipher }
                    )
                    if cipher.id != ciphers.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
        .frame(maxHeight: 380)
        .sheet(item: $selectedCipher) { cipher in
            CipherDetailView(cipher: cipher, totpService: totpService)
        }
    }
}

// MARK: - CipherRowView

struct CipherRowView: View {

    let cipher: Cipher
    let totpService: TOTPService
    let onDelete: () -> Void
    let onSelect: () -> Void

    @State private var copyFeedback: String?

    private var actionState: CipherRowActionState {
        CipherRowActionState(cipher: cipher)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            CipherIcon(cipher: cipher)
                .frame(width: 28, height: 28)

            // Name + subtitle
            VStack(alignment: .leading, spacing: 1) {
                Text(cipher.name)
                    .font(.callout)
                    .lineLimit(1)
                if let sub = cipher.subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if actionState.canLaunch {
                    Button {
                        launchCipher()
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(.plain)
                    .help("Launch")
                }

                if actionState.hasCopyActions {
                    Menu {
                        copyMenuItems
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .help("Copy")
                }

                if actionState.hasMoreActions {
                    Menu {
                        moreActionsMenuItems
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .help("More actions")
                }
            }

            if let feedback = copyFeedback {
                Text(feedback)
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    @ViewBuilder
    private var copyMenuItems: some View {
        if let username = actionState.copyUsername {
            Button {
                copyToClipboard(username, feedback: "Username copied")
            } label: {
                Label("Copy Username", systemImage: "person")
            }
        }

        if let password = actionState.copyPassword {
            Button {
                copyToClipboard(password, feedback: "Password copied")
            } label: {
                Label("Copy Password", systemImage: "key")
            }
        }
    }

    @ViewBuilder
    private var moreActionsMenuItems: some View {
        if actionState.canLaunch {
            Button {
                launchCipher()
            } label: {
                Label("Launch", systemImage: "arrow.up.forward.square")
            }
        }

        if let username = actionState.copyUsername {
            Button {
                copyToClipboard(username, feedback: "Username copied")
            } label: {
                Label("Copy Username", systemImage: "person")
            }
        }

        if let password = actionState.copyPassword {
            Button {
                copyToClipboard(password, feedback: "Password copied")
            } label: {
                Label("Copy Password", systemImage: "key")
            }
        }

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        copyMenuItems

        if let totp = cipher.login?.totp, !totp.isEmpty,
           let code = totpService.generateCode(from: totp) {
            Button {
                copyToClipboard(code.code, feedback: "TOTP copied")
            } label: {
                Label("Copy TOTP (\(code.code))", systemImage: "clock")
            }
        }

        if cipher.type == .card,
           let number = cipher.card?.number, !number.isEmpty {
            Button {
                copyToClipboard(number, feedback: "Card number copied")
            } label: {
                Label("Copy Card Number", systemImage: "creditcard")
            }
        }

        Divider()
        moreActionsMenuItems
    }

    private func launchCipher() {
        guard let launchURL = actionState.launchURL else { return }
        NSWorkspace.shared.open(launchURL)
    }

    private func copyToClipboard(_ string: String, feedback: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)

        withAnimation {
            copyFeedback = "✓ \(feedback)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copyFeedback = nil }
        }
    }
}

// MARK: - CipherRowActionState

struct CipherRowActionState {
    let cipher: Cipher

    var copyUsername: String? {
        nonEmpty(cipher.login?.username)
    }

    var copyPassword: String? {
        nonEmpty(cipher.login?.password)
    }

    var hasCopyActions: Bool {
        copyUsername != nil || copyPassword != nil
    }

    var launchURL: URL? {
        guard cipher.type == .login else { return nil }

        for uri in cipher.login?.uris ?? [] {
            guard uri.match != .regularExpression,
                  let rawValue = nonEmpty(uri.uri),
                  let normalized = normalizeLaunchURL(from: rawValue) else {
                continue
            }
            return normalized
        }

        return nil
    }

    var canLaunch: Bool {
        launchURL != nil
    }

    var hasMoreActions: Bool {
        true
    }

    // This change keeps launch stateless; BitwardenBar does not yet persist last-launched metadata.
    private func normalizeLaunchURL(from value: String) -> URL? {
        if value.contains("://") {
            guard let url = URL(string: value),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme) else {
                return nil
            }
            return url
        }

        guard looksLikeWebsite(value),
              let url = URL(string: "http://\(value)") else {
            return nil
        }

        return url
    }

    private func looksLikeWebsite(_ value: String) -> Bool {
        guard !value.contains(" "), value.contains(".") else { return false }
        let candidate = value.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first ?? ""
        return candidate.contains(".")
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

// MARK: - CipherIcon

struct CipherIcon: View {
    let cipher: Cipher

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(iconColor.opacity(0.15))
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
        }
    }

    private var iconName: String {
        switch cipher.type {
        case .login:
            if let uri = cipher.login?.uris?.first?.uri, !uri.isEmpty {
                return "globe"
            }
            return "key.fill"
        case .secureNote: return "note.text"
        case .card: return "creditcard.fill"
        case .identity: return "person.fill"
        case .sshKey: return "key.radiowaves.forward"
        }
    }

    private var iconColor: Color {
        switch cipher.type {
        case .login: return .blue
        case .secureNote: return .yellow
        case .card: return .purple
        case .identity: return .green
        case .sshKey: return .orange
        }
    }
}
