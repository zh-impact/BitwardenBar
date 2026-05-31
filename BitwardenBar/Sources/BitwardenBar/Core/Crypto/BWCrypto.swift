import Foundation
import CommonCrypto
import CryptoKit

// MARK: - VaultKey

/// Holds the 32-byte AES-256 encryption key and 32-byte HMAC-SHA256 MAC key for a vault session.
struct VaultKey {
    let encKey: Data  // 32 bytes — used for AES-256-CBC decryption
    let macKey: Data  // 32 bytes — used for HMAC-SHA256 verification

    var combined: Data {
        var data = Data()
        data.append(encKey)
        data.append(macKey)
        return data
    }

    init(encKey: Data, macKey: Data) {
        self.encKey = encKey
        self.macKey = macKey
    }

    /// Initialise from a 64-byte combined key (first 32 = enc, last 32 = mac).
    init(combined: Data) {
        precondition(combined.count == 64, "VaultKey combined data must be 64 bytes")
        let start = combined.startIndex
        let mid   = combined.index(start, offsetBy: 32)
        encKey = Data(combined[start..<mid])
        macKey = Data(combined[mid...])
    }
}

// MARK: - BWEncString

/// Represents a Bitwarden AES-256-CBC + HMAC-SHA256 encrypted value (EncString type 2).
/// Wire format: `2.<iv_base64>|<ciphertext_base64>|<mac_base64>`
struct BWEncString {
    let iv: Data          // 16 bytes — AES CBC initialisation vector
    let ciphertext: Data  // variable — AES-256-CBC encrypted payload
    let mac: Data         // 32 bytes — HMAC-SHA256 over (iv ‖ ciphertext)

    /// Returns `nil` when the string is not a type-2 EncString or is malformed.
    init?(raw: String) {
        guard let dotIdx = raw.firstIndex(of: "."),
              let typeInt = Int(String(raw[..<dotIdx])),
              typeInt == 2               // only AES-256-CBC+HMAC is supported here
        else { return nil }

        let rest  = String(raw[raw.index(after: dotIdx)...])
        let parts = rest.split(separator: "|", maxSplits: 2).map(String.init)
        guard parts.count == 3,
              let iv  = Data(base64Encoded: parts[0]),
              let ct  = Data(base64Encoded: parts[1]),
              let mac = Data(base64Encoded: parts[2])
        else { return nil }

        self.iv         = iv
        self.ciphertext = ct
        self.mac        = mac
    }
}

// MARK: - BWCryptoError

enum BWCryptoError: LocalizedError {
    case keyDerivationFailed
    case decryptionFailed
    case macVerificationFailed
    case argon2idNotSupported
    case invalidKeyLength
    case invalidCiphertext
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .keyDerivationFailed:
            return "Key derivation failed."
        case .decryptionFailed:
            return "AES-CBC decryption failed."
        case .macVerificationFailed:
            return "HMAC verification failed — wrong master password or corrupted data."
        case .argon2idNotSupported:
            return "Argon2id KDF is not supported in this build. Change your Bitwarden KDF to PBKDF2 in Account Settings → Security → Keys."
        case .invalidKeyLength:
            return "Unexpected key length."
        case .invalidCiphertext:
            return "Ciphertext is not a recognised Bitwarden EncString."
        case .invalidEncoding:
            return "Decrypted bytes are not valid UTF-8."
        }
    }
}

// MARK: - BWCrypto

/// Pure-Swift implementation of the Bitwarden client-side crypto algorithms.
///
/// Key hierarchy (password-based unlock):
/// ```
///   masterKey  = PBKDF2-SHA256(password, email, N)         32 bytes
///   encKey     = HKDF-Expand(PRK=masterKey, info="enc", 32) 32 bytes  ┐ stretchedKey
///   macKey     = HKDF-Expand(PRK=masterKey, info="mac", 32) 32 bytes  ┘
///   userKey    = AES-256-CBC-Decrypt(server_key_field, stretchedKey) → 64 bytes
///   vaultEncKey = userKey[0..<32]   vaultMacKey = userKey[32..<64]
/// ```
enum BWCrypto {

    // MARK: - Key Derivation

    /// Derives the master key from the master password using PBKDF2-SHA256.
    ///
    /// - Parameters:
    ///   - password: The user's master password (UTF-8).
    ///   - email:    The user's email address (lowercased, UTF-8) — used as the PBKDF2 salt.
    ///   - iterations: KDF iterations (typically 600 000 for PBKDF2).
    /// - Returns: 32-byte master key.
    static func derivePBKDF2MasterKey(password: String, email: String, iterations: Int) throws -> Data {
        guard let passwordData = password.data(using: .utf8),
              let saltData     = email.lowercased().data(using: .utf8) else {
            throw BWCryptoError.keyDerivationFailed
        }
        return try pbkdf2SHA256(password: passwordData, salt: saltData, rounds: iterations, keyLength: 32)
    }

    /// Computes the master password hash sent to the Bitwarden server for authentication.
    ///
    /// `serverHash = base64(PBKDF2-SHA256(password: masterKey, salt: password_bytes, rounds: 1))`
    static func serverPasswordHash(masterKey: Data, password: String) throws -> String {
        guard let passwordSalt = password.data(using: .utf8) else {
            throw BWCryptoError.keyDerivationFailed
        }
        let hash = try pbkdf2SHA256(password: masterKey, salt: passwordSalt, rounds: 1, keyLength: 32)
        return hash.base64EncodedString()
    }

    /// Stretches a 32-byte master key into a `VaultKey` using HKDF-Expand (no Extract step).
    ///
    /// ```
    /// encKey = HKDF-Expand(PRK=masterKey, info="enc", L=32)
    /// macKey = HKDF-Expand(PRK=masterKey, info="mac", L=32)
    /// ```
    static func stretchKey(_ masterKey: Data) -> VaultKey {
        let encKey = hkdfExpand(prk: masterKey, info: Data("enc".utf8), length: 32)
        let macKey = hkdfExpand(prk: masterKey, info: Data("mac".utf8), length: 32)
        return VaultKey(encKey: encKey, macKey: macKey)
    }

    // MARK: - Decryption

    /// Decrypts a `BWEncString` to raw `Data` using the provided `VaultKey`.
    /// Verifies the HMAC before decryption (encrypt-then-MAC scheme).
    static func decrypt(_ enc: BWEncString, using key: VaultKey) throws -> Data {
        // Constant-time HMAC verification: HMAC-SHA256(macKey, iv ‖ ciphertext)
        var macInput = enc.iv
        macInput.append(enc.ciphertext)
        guard HMAC<SHA256>.isValidAuthenticationCode(
            enc.mac,
            authenticating: macInput,
            using: SymmetricKey(data: key.macKey)
        ) else {
            throw BWCryptoError.macVerificationFailed
        }
        return try aesCBCDecrypt(data: enc.ciphertext, key: key.encKey, iv: enc.iv)
    }

    /// Decrypts a raw Bitwarden EncString value to a UTF-8 `String`.
    static func decryptToString(_ raw: String, using key: VaultKey) throws -> String {
        guard let enc = BWEncString(raw: raw) else { throw BWCryptoError.invalidCiphertext }
        let data = try decrypt(enc, using: key)
        guard let str = String(data: data, encoding: .utf8) else { throw BWCryptoError.invalidEncoding }
        return str
    }

    /// Decrypts an optional EncString field — returns `nil` when `raw` is `nil`.
    static func decryptOptional(_ raw: String?, using key: VaultKey) throws -> String? {
        guard let raw else { return nil }
        return try decryptToString(raw, using: key)
    }

    // MARK: - Private Helpers

    /// HKDF-Expand only (RFC 5869 §2.3) using HMAC-SHA256.
    ///
    /// For L ≤ 32 bytes (one hash block), this reduces to:
    ///   T(1) = HMAC-SHA256(PRK, info ‖ 0x01)
    private static func hkdfExpand(prk: Data, info: Data, length: Int) -> Data {
        // CryptoKit's HKDF.expand performs the Expand step only — identical to the above.
        let key = HKDF<SHA256>.expand(
            pseudoRandomKey: prk,
            info: info,
            outputByteCount: length
        )
        return key.withUnsafeBytes { Data($0) }
    }

    /// PBKDF2-SHA256 key derivation via CommonCrypto.
    private static func pbkdf2SHA256(
        password: Data,
        salt: Data,
        rounds: Int,
        keyLength: Int
    ) throws -> Data {
        var derivedKey = [UInt8](repeating: 0, count: keyLength)
        let status: CCStatus = password.withUnsafeBytes { passwordBuf in
            salt.withUnsafeBytes { saltBuf in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBuf.baseAddress?.assumingMemoryBound(to: Int8.self),
                    password.count,
                    saltBuf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(rounds),
                    &derivedKey,
                    keyLength
                )
            }
        }
        guard status == kCCSuccess else { throw BWCryptoError.keyDerivationFailed }
        return Data(derivedKey)
    }

    /// AES-256-CBC decryption with PKCS7 padding via CommonCrypto.
    private static func aesCBCDecrypt(data: Data, key: Data, iv: Data) throws -> Data {
        guard key.count == kCCKeySizeAES256 else { throw BWCryptoError.invalidKeyLength }
        guard iv.count  == kCCBlockSizeAES128 else { throw BWCryptoError.invalidKeyLength }

        let bufferSize = data.count + kCCBlockSizeAES128
        var outputBuffer = [UInt8](repeating: 0, count: bufferSize)
        var outputCount  = 0

        let status: CCStatus = data.withUnsafeBytes { dataBuf in
            key.withUnsafeBytes { keyBuf in
                iv.withUnsafeBytes { ivBuf in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES128),  // same constant as kCCAlgorithmAES
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBuf.baseAddress, key.count,
                        ivBuf.baseAddress,
                        dataBuf.baseAddress, data.count,
                        &outputBuffer, bufferSize,
                        &outputCount
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw BWCryptoError.decryptionFailed }
        return Data(outputBuffer[..<outputCount])
    }
}
