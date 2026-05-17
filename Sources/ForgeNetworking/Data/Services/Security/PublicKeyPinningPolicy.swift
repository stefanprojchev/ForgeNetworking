import Foundation
import Security

/// A `PinningPolicy` that pins public keys per host.
///
/// Public key pinning is more rotation-friendly than certificate pinning: you can
/// renew the certificate without updating the pin, as long as the same key pair is
/// reused. If the public key of any certificate in the server's chain matches one
/// of the pinned keys for that host, the connection is allowed.
///
/// ## Extracting a public key from a DER certificate
/// ```swift
/// guard let url = Bundle.main.url(forResource: "api-example-com", withExtension: "der"),
///       let der = try? Data(contentsOf: url),
///       let cert = SecCertificateCreateWithData(nil, der as CFData),
///       let publicKey = SecCertificateCopyKey(cert) else { fatalError("missing pinned key") }
///
/// let policy = PublicKeyPinningPolicy(["api.example.com": [publicKey]])
/// ```
///
/// ## Sendable note
/// `SecKey` is a Core Foundation opaque reference type with thread-safe immutable
/// semantics. The struct is marked `@unchecked Sendable` because Swift's type system
/// cannot verify `SecKey` conformance automatically.
///
/// ## Chain validation
/// When `validateChain` is `true` (the default), `SecTrustEvaluateWithError` is
/// called first, confirming the chain is signed by a trusted root CA and has not
/// expired. Disable only in controlled environments — never in production.
public struct PublicKeyPinningPolicy: PinningPolicy, @unchecked Sendable {

    // MARK: - Dependencies

    /// Pinned public keys keyed by hostname.
    public let pinnedKeys: [String: [SecKey]]

    /// When `true`, the chain is validated via `SecTrustEvaluateWithError` before
    /// comparing public keys. Defaults to `true`. Set to `false` only in test
    /// environments (e.g., against a server with a self-signed cert).
    public let validateChain: Bool

    // MARK: - Init

    /// Creates a public key pinning policy.
    ///
    /// - Parameters:
    ///   - map: A dictionary mapping hostnames to arrays of pinned `SecKey` objects.
    ///   - validateChain: Whether to call `SecTrustEvaluateWithError` before comparing.
    ///     Defaults to `true`.
    public init(_ map: [String: [SecKey]], validateChain: Bool = true) {
        self.pinnedKeys = map
        self.validateChain = validateChain
    }

    // MARK: - Implementation

    public func evaluate(serverTrust: SecTrust, host: String) -> PinningResult {
        guard let pinnedForHost = pinnedKeys[host], !pinnedForHost.isEmpty else {
            return .notApplicable
        }

        if validateChain {
            var error: CFError?
            guard SecTrustEvaluateWithError(serverTrust, &error) else { return .reject }
        }

        let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] ?? []
        for cert in chain {
            guard
                let serverKey = SecCertificateCopyKey(cert),
                let serverKeyData = SecKeyCopyExternalRepresentation(serverKey, nil) as Data?
            else { continue }

            for pinnedKey in pinnedForHost {
                if let pinnedData = SecKeyCopyExternalRepresentation(pinnedKey, nil) as Data?,
                   serverKeyData == pinnedData {
                    return .allow
                }
            }
        }
        return .reject
    }
}
