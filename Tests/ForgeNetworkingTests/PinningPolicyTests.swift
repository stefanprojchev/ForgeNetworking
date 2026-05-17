import Testing
import Foundation
import Security
@testable import ForgeNetworking

// NOTE: The `.allow` path with chain validation (`validateChain: true`) requires a
// certificate issued by a trusted root CA. These tests use a self-signed cert, so
// `SecTrustEvaluateWithError` will return false for it; all allow-path tests set
// `validateChain: false` to isolate the byte/key matching logic. The full
// validated-pinning path is exercised in integration tests against a real server.

// MARK: - Embedded test certificate
//
// A self-signed EC P-256 cert for CN=test.example.com, valid 10 years.
// Generated with: openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256
//                   -keyout /tmp/k.pem -out /tmp/c.pem -days 3650 -nodes
//                   -subj "/CN=test.example.com"
// Then: openssl x509 -in /tmp/c.pem -outform DER -out /tmp/c.der
private let testCertDERBytes: [UInt8] = [
    0x30, 0x82, 0x01, 0x8B, 0x30, 0x82, 0x01, 0x31, 0xA0, 0x03, 0x02, 0x01, 0x02, 0x02, 0x14,
    0x3C, 0x0B, 0x44, 0x47, 0x47, 0xDD, 0x74, 0x6B, 0xF9, 0x67, 0x57, 0xA0, 0x40, 0x29, 0x5E,
    0xD2, 0xE3, 0x86, 0x4F, 0xFE, 0x30, 0x0A, 0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04,
    0x03, 0x02, 0x30, 0x1B, 0x31, 0x19, 0x30, 0x17, 0x06, 0x03, 0x55, 0x04, 0x03, 0x0C, 0x10,
    0x74, 0x65, 0x73, 0x74, 0x2E, 0x65, 0x78, 0x61, 0x6D, 0x70, 0x6C, 0x65, 0x2E, 0x63, 0x6F,
    0x6D, 0x30, 0x1E, 0x17, 0x0D, 0x32, 0x36, 0x30, 0x35, 0x31, 0x37, 0x30, 0x38, 0x33, 0x37,
    0x34, 0x30, 0x5A, 0x17, 0x0D, 0x33, 0x36, 0x30, 0x35, 0x31, 0x34, 0x30, 0x38, 0x33, 0x37,
    0x34, 0x30, 0x5A, 0x30, 0x1B, 0x31, 0x19, 0x30, 0x17, 0x06, 0x03, 0x55, 0x04, 0x03, 0x0C,
    0x10, 0x74, 0x65, 0x73, 0x74, 0x2E, 0x65, 0x78, 0x61, 0x6D, 0x70, 0x6C, 0x65, 0x2E, 0x63,
    0x6F, 0x6D, 0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01,
    0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00, 0x04, 0xEF,
    0x03, 0x4C, 0x5A, 0x4C, 0x52, 0xE3, 0xE0, 0x2B, 0x3C, 0xC4, 0x52, 0xA9, 0xFD, 0x39, 0x58,
    0x4A, 0x77, 0xA0, 0xA1, 0x66, 0xA6, 0x13, 0xD6, 0xE4, 0x81, 0x2E, 0xA8, 0x75, 0x45, 0xB9,
    0xE3, 0xE0, 0x60, 0xAF, 0xF5, 0x12, 0xA3, 0xD7, 0xBE, 0x6E, 0x03, 0x2A, 0x3E, 0x79, 0x74,
    0x6D, 0x65, 0xE3, 0xC8, 0x1B, 0x03, 0x71, 0x97, 0x52, 0x74, 0x10, 0x13, 0x0A, 0xED, 0x96,
    0x90, 0xFF, 0x86, 0xA3, 0x53, 0x30, 0x51, 0x30, 0x1D, 0x06, 0x03, 0x55, 0x1D, 0x0E, 0x04,
    0x16, 0x04, 0x14, 0x32, 0xA1, 0x91, 0xFC, 0xF5, 0x3A, 0x58, 0x1E, 0xDC, 0x18, 0x93, 0x78,
    0x35, 0x39, 0x1D, 0x04, 0x02, 0x0D, 0xEB, 0x06, 0x30, 0x1F, 0x06, 0x03, 0x55, 0x1D, 0x23,
    0x04, 0x18, 0x30, 0x16, 0x80, 0x14, 0x32, 0xA1, 0x91, 0xFC, 0xF5, 0x3A, 0x58, 0x1E, 0xDC,
    0x18, 0x93, 0x78, 0x35, 0x39, 0x1D, 0x04, 0x02, 0x0D, 0xEB, 0x06, 0x30, 0x0F, 0x06, 0x03,
    0x55, 0x1D, 0x13, 0x01, 0x01, 0xFF, 0x04, 0x05, 0x30, 0x03, 0x01, 0x01, 0xFF, 0x30, 0x0A,
    0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02, 0x03, 0x48, 0x00, 0x30, 0x45,
    0x02, 0x21, 0x00, 0xEF, 0x5D, 0xD1, 0x59, 0x84, 0x64, 0xAA, 0xD5, 0x50, 0xE9, 0x11, 0xF7,
    0x70, 0xE8, 0x2D, 0x18, 0x4F, 0xC2, 0x4B, 0x34, 0xCD, 0x71, 0x67, 0x2C, 0xB0, 0x22, 0x29,
    0xB5, 0x1D, 0xB9, 0x9A, 0x7A, 0x02, 0x20, 0x43, 0x27, 0x83, 0xA4, 0x01, 0x99, 0xD4, 0x55,
    0xB0, 0x46, 0xBB, 0x60, 0x54, 0xF1, 0x2E, 0x5D, 0xD8, 0x38, 0x6E, 0x40, 0x71, 0x1E, 0x54,
    0xEB, 0x60, 0x0B, 0xBB, 0x49, 0xF1, 0x3F, 0xB4, 0x6C,
]

@Suite("Pinning policies")
struct PinningPolicyTests {

    // MARK: - Helpers

    /// Creates a `SecCertificate` from the embedded test DER bytes.
    private func makeTestCert() throws -> SecCertificate {
        let data = Data(testCertDERBytes)
        guard let cert = SecCertificateCreateWithData(nil, data as CFData) else {
            throw NSError(domain: "PinningPolicyTests", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create SecCertificate from test DER"])
        }
        return cert
    }

    /// Creates a `SecTrust` from the given certificates and an SSL policy (no hostname check).
    private func makeTrust(certs: [SecCertificate]) throws -> SecTrust {
        let sslPolicy = SecPolicyCreateSSL(false, nil)
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certs as CFArray, sslPolicy, &trust)
        guard status == errSecSuccess, let t = trust else {
            throw NSError(domain: "PinningPolicyTests", code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "SecTrustCreateWithCertificates failed: \(status)"])
        }
        return t
    }

    /// Returns the DER bytes of the embedded test certificate.
    private var testCertDER: Data { Data(testCertDERBytes) }

    /// Extracts the public key from the embedded test certificate.
    private func testCertPublicKey() throws -> SecKey {
        let cert = try makeTestCert()
        guard let key = SecCertificateCopyKey(cert) else {
            throw NSError(domain: "PinningPolicyTests", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Could not copy public key from test cert"])
        }
        return key
    }

    // MARK: - CertificatePinningPolicy — notApplicable

    @Test("CertificatePinningPolicy returns .notApplicable for host not in map")
    func certPolicyNotApplicable() throws {
        let policy = CertificatePinningPolicy(
            ["other.host": [testCertDER]],
            validateChain: false
        )
        let cert = try makeTestCert()
        let trust = try makeTrust(certs: [cert])
        #expect(policy.evaluate(serverTrust: trust, host: "api.example.com") == .notApplicable)
    }

    @Test("CertificatePinningPolicy returns .notApplicable for empty policy map")
    func certPolicyEmptyMap() throws {
        let policy = CertificatePinningPolicy([:], validateChain: false)
        let cert = try makeTestCert()
        let trust = try makeTrust(certs: [cert])
        #expect(policy.evaluate(serverTrust: trust, host: "api.example.com") == .notApplicable)
    }

    // MARK: - CertificatePinningPolicy — allow (no chain validation)

    @Test("CertificatePinningPolicy allows when cert DER matches (validateChain: false)")
    func certPolicyAllowsMatchingCert() throws {
        let cert = try makeTestCert()
        let trust = try makeTrust(certs: [cert])
        let policy = CertificatePinningPolicy(
            ["api.example.com": [testCertDER]],
            validateChain: false
        )
        #expect(policy.evaluate(serverTrust: trust, host: "api.example.com") == .allow)
    }

    // MARK: - CertificatePinningPolicy — reject

    @Test("CertificatePinningPolicy rejects when cert DER doesn't match")
    func certPolicyRejectsWrongCert() throws {
        let cert = try makeTestCert()
        let trust = try makeTrust(certs: [cert])
        let policy = CertificatePinningPolicy(
            ["api.example.com": [Data([0xDE, 0xAD, 0xBE, 0xEF])]],
            validateChain: false
        )
        #expect(policy.evaluate(serverTrust: trust, host: "api.example.com") == .reject)
    }

    @Test("CertificatePinningPolicy rejects when pin list is empty for mapped host")
    func certPolicyRejectsEmptyPinList() throws {
        let cert = try makeTestCert()
        let trust = try makeTrust(certs: [cert])
        let policy = CertificatePinningPolicy(["api.example.com": []], validateChain: false)
        #expect(policy.evaluate(serverTrust: trust, host: "api.example.com") == .reject)
    }

    @Test("CertificatePinningPolicy rejects self-signed cert when validateChain is true")
    func certPolicyRejectsSelfSignedWithChainValidation() throws {
        let cert = try makeTestCert()
        let trust = try makeTrust(certs: [cert])
        // validateChain: true — SecTrustEvaluateWithError rejects the self-signed cert.
        let policy = CertificatePinningPolicy(
            ["api.example.com": [testCertDER]],
            validateChain: true
        )
        #expect(policy.evaluate(serverTrust: trust, host: "api.example.com") == .reject)
    }

    // MARK: - PublicKeyPinningPolicy — notApplicable

    @Test("PublicKeyPinningPolicy returns .notApplicable for host not in map")
    func keyPolicyNotApplicable() throws {
        let publicKey = try testCertPublicKey()
        let policy = PublicKeyPinningPolicy(
            ["other.host": [publicKey]],
            validateChain: false
        )
        let cert = try makeTestCert()
        let trust = try makeTrust(certs: [cert])
        #expect(policy.evaluate(serverTrust: trust, host: "api.example.com") == .notApplicable)
    }

    @Test("PublicKeyPinningPolicy returns .notApplicable for empty policy map")
    func keyPolicyEmptyMap() throws {
        let policy = PublicKeyPinningPolicy([:], validateChain: false)
        let cert = try makeTestCert()
        let trust = try makeTrust(certs: [cert])
        #expect(policy.evaluate(serverTrust: trust, host: "api.example.com") == .notApplicable)
    }

    @Test("PublicKeyPinningPolicy returns .notApplicable when host maps to empty key list")
    func keyPolicyEmptyKeyList() throws {
        let policy = PublicKeyPinningPolicy(["api.example.com": []], validateChain: false)
        let cert = try makeTestCert()
        let trust = try makeTrust(certs: [cert])
        // Empty array triggers the `!pinnedForHost.isEmpty` guard → .notApplicable.
        #expect(policy.evaluate(serverTrust: trust, host: "api.example.com") == .notApplicable)
    }

    // MARK: - PublicKeyPinningPolicy — allow (no chain validation)

    @Test("PublicKeyPinningPolicy allows when public key matches (validateChain: false)")
    func keyPolicyAllowsMatchingKey() throws {
        let cert = try makeTestCert()
        let trust = try makeTrust(certs: [cert])
        let publicKey = try testCertPublicKey()
        let policy = PublicKeyPinningPolicy(
            ["api.example.com": [publicKey]],
            validateChain: false
        )
        #expect(policy.evaluate(serverTrust: trust, host: "api.example.com") == .allow)
    }

    // MARK: - PublicKeyPinningPolicy — reject

    @Test("PublicKeyPinningPolicy rejects when a different key is pinned")
    func keyPolicyRejectsWrongKey() throws {
        let cert = try makeTestCert()
        let trust = try makeTrust(certs: [cert])

        // Generate a fresh ephemeral key that doesn't match the cert's key.
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
        ]
        var cfErr: Unmanaged<CFError>?
        guard let privKey = SecKeyCreateRandomKey(attrs as CFDictionary, &cfErr),
              let differentKey = SecKeyCopyPublicKey(privKey) else {
            throw cfErr!.takeRetainedValue() as Error
        }

        let policy = PublicKeyPinningPolicy(
            ["api.example.com": [differentKey]],
            validateChain: false
        )
        #expect(policy.evaluate(serverTrust: trust, host: "api.example.com") == .reject)
    }

    @Test("PublicKeyPinningPolicy rejects self-signed cert when validateChain is true")
    func keyPolicyRejectsSelfSignedWithChainValidation() throws {
        let cert = try makeTestCert()
        let trust = try makeTrust(certs: [cert])
        let publicKey = try testCertPublicKey()
        // validateChain: true — SecTrustEvaluateWithError rejects the self-signed cert.
        let policy = PublicKeyPinningPolicy(
            ["api.example.com": [publicKey]],
            validateChain: true
        )
        #expect(policy.evaluate(serverTrust: trust, host: "api.example.com") == .reject)
    }

    // MARK: - PinningResult equality

    @Test("PinningResult cases are equatable")
    func pinningResultEquality() {
        #expect(PinningResult.allow == .allow)
        #expect(PinningResult.reject == .reject)
        #expect(PinningResult.notApplicable == .notApplicable)
        #expect(PinningResult.allow != .reject)
        #expect(PinningResult.reject != .notApplicable)
        #expect(PinningResult.allow != .notApplicable)
    }
}
