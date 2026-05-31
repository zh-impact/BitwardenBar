import Foundation
import CryptoKit

// MARK: - TOTPService

/// Generates TOTP codes from a stored TOTP secret (otpauth URI or raw Base32 secret).
/// Implements RFC 6238 using CryptoKit — no external dependency needed.
final class TOTPService {

    // MARK: - Code Generation

    struct TOTPCode {
        let code: String
        let timeRemaining: Int   // seconds until this code expires
        let period: Int          // code refresh period (default 30s)
    }

    func generateCode(from totpString: String) -> TOTPCode? {
        guard let secret = parseSecret(from: totpString) else { return nil }
        let period = parsePeriod(from: totpString) ?? 30
        let digits = parseDigits(from: totpString) ?? 6

        let now = Int(Date().timeIntervalSince1970)
        let counter = UInt64(now / period)
        let timeRemaining = period - (now % period)

        guard let code = hotp(secret: secret, counter: counter, digits: digits) else { return nil }
        return TOTPCode(code: code, timeRemaining: timeRemaining, period: period)
    }

    // MARK: - Private

    private func hotp(secret: Data, counter: UInt64, digits: Int) -> String? {
        var counterBigEndian = counter.bigEndian
        let counterData = Data(bytes: &counterBigEndian, count: MemoryLayout<UInt64>.size)

        let key = SymmetricKey(data: secret)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let hmacData = Data(hmac)

        let offset = Int(hmacData[hmacData.count - 1] & 0x0F)
        let truncated = (UInt32(hmacData[offset]) & 0x7F) << 24
            | UInt32(hmacData[offset + 1]) << 16
            | UInt32(hmacData[offset + 2]) << 8
            | UInt32(hmacData[offset + 3])

        let divisor = UInt32(pow(10.0, Double(digits)))
        let code = Int(truncated % divisor)
        return String(format: "%0*d", digits, code)
    }

    private func parseSecret(from totpString: String) -> Data? {
        if totpString.lowercased().hasPrefix("otpauth://") {
            // otpauth://totp/label?secret=BASE32&...
            guard let url = URL(string: totpString),
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let secretItem = components.queryItems?.first(where: { $0.name.lowercased() == "secret" }),
                  let secretValue = secretItem.value else { return nil }
            return base32Decode(secretValue)
        } else {
            // Raw base32 secret
            return base32Decode(totpString)
        }
    }

    private func parsePeriod(from totpString: String) -> Int? {
        guard totpString.lowercased().hasPrefix("otpauth://"),
              let url = URL(string: totpString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let item = components.queryItems?.first(where: { $0.name.lowercased() == "period" }),
              let value = item.value else { return nil }
        return Int(value)
    }

    private func parseDigits(from totpString: String) -> Int? {
        guard totpString.lowercased().hasPrefix("otpauth://"),
              let url = URL(string: totpString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let item = components.queryItems?.first(where: { $0.name.lowercased() == "digits" }),
              let value = item.value else { return nil }
        return Int(value)
    }

    // MARK: - Base32 Decoding

    private func base32Decode(_ input: String) -> Data? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let cleaned = input.uppercased().filter { alphabet.contains($0) }
        guard !cleaned.isEmpty else { return nil }

        var bits = 0
        var value = 0
        var output = Data()

        for char in cleaned {
            guard let index = alphabet.firstIndex(of: char) else { continue }
            let distance = alphabet.distance(from: alphabet.startIndex, to: index)
            value = (value << 5) | distance
            bits += 5
            if bits >= 8 {
                output.append(UInt8((value >> (bits - 8)) & 0xFF))
                bits -= 8
            }
        }
        return output
    }
}
