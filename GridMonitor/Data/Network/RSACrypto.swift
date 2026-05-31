import Foundation
import Security

/// RSA-шифрування пароля під логін FSolar — дзеркалить JSEncrypt у веб-застосунку:
/// `password = base64( RSA_PKCS1v1.5_encrypt(plaintext, publicKey) )`.
///
/// Публічний ключ зашитий у фронтенд FSolar у форматі X.509 SubjectPublicKeyInfo (base64).
/// Security.framework очікує «сирий» PKCS#1 RSAPublicKey, тому ASN.1-заголовок SPKI знімаємо.
enum RSACrypto {

    /// Публічний ключ FSolar (SPKI, base64). Джерело: docs/fsolar-api.md §1.
    static let fsolarPublicKeySPKIBase64 = """
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnAJE68pjWZmtSg6ZJs9FZugJXC6bBSluTW6mJttOLOaljrdErVnM5DNN+YFzpB9pAysTErjY1bnSVuEwQSwptnqUji7Ch2qMj2n+0eCp8p6vtSh7/tFr2ul8nDRtkoswLANAIwtUk/G85ipMpmY1W642LImnEJmGkkddlbjbjxJTZWR5hc/d9cPWb+AR77LxFFrMik3c+44v1kQlIPFP6EjIbOvt/Lv7fHWD9JI/YzN4y1gK7C/VQdNGuikQyNg+5W3rg9ecYf9I5uLAQwY/hxeI3lbNsErebqKe2EbJ8AwcNIC0lDBz53Sq0ML89QapEuy3fB+upuctxLULVDCbNwIDAQAB
    """

    enum CryptoError: Error { case badKey, badInput, encryptFailed(String) }

    /// Зашифрувати рядок ключем у форматі SPKI(base64) і повернути base64-результат.
    static func encrypt(_ plaintext: String, spkiBase64: String = fsolarPublicKeySPKIBase64) throws -> String {
        let cleaned = spkiBase64.replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let spki = Data(base64Encoded: cleaned) else { throw CryptoError.badKey }
        let pkcs1 = try stripSPKIHeader(spki)

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048,
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(pkcs1 as CFData, attributes as CFDictionary, &error) else {
            throw CryptoError.encryptFailed((error?.takeRetainedValue()).map { "\($0)" } ?? "SecKeyCreateWithData")
        }
        guard let data = plaintext.data(using: .utf8) else { throw CryptoError.badInput }
        guard let cipher = SecKeyCreateEncryptedData(key, .rsaEncryptionPKCS1, data as CFData, &error) else {
            throw CryptoError.encryptFailed((error?.takeRetainedValue()).map { "\($0)" } ?? "encrypt")
        }
        return (cipher as Data).base64EncodedString()
    }

    /// Зняти ASN.1-заголовок SubjectPublicKeyInfo, повернувши сирий PKCS#1 RSAPublicKey.
    /// Розбираємо DER: SEQUENCE { AlgorithmIdentifier, BIT STRING { RSAPublicKey } }.
    private static func stripSPKIHeader(_ der: Data) throws -> Data {
        var bytes = [UInt8](der)
        var i = 0
        func readLength() throws -> Int {
            guard i < bytes.count else { throw CryptoError.badKey }
            let first = bytes[i]; i += 1
            if first & 0x80 == 0 { return Int(first) }
            let count = Int(first & 0x7F)
            guard count > 0, i + count <= bytes.count else { throw CryptoError.badKey }
            var len = 0
            for _ in 0..<count { len = (len << 8) | Int(bytes[i]); i += 1 }
            return len
        }
        // зовнішній SEQUENCE
        guard i < bytes.count, bytes[i] == 0x30 else { throw CryptoError.badKey }
        i += 1; _ = try readLength()
        // AlgorithmIdentifier SEQUENCE — пропустити цілком
        guard i < bytes.count, bytes[i] == 0x30 else { throw CryptoError.badKey }
        i += 1; let algLen = try readLength(); i += algLen
        // BIT STRING
        guard i < bytes.count, bytes[i] == 0x03 else { throw CryptoError.badKey }
        i += 1; _ = try readLength()
        // перший байт BIT STRING — кількість невикористаних бітів (має бути 0)
        guard i < bytes.count, bytes[i] == 0x00 else { throw CryptoError.badKey }
        i += 1
        return Data(bytes[i...])
    }
}
