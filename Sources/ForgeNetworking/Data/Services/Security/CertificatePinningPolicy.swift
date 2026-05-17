import Foundation
import Security

/// A `PinningPolicy` that pins entire DER-encoded certificate bytes per host.
///
/// If the server's leaf certificate — or any certificate in the chain — matches
/// one of the pinned `Data` blobs for that host, the connection is allowed.
/// If the host is in the policy map but no certificate matches, the connection
/// is rejected. If the host is not in the map, `.notApplicable` is returned and
/// URLSession performs its default OS trust evaluation.
///
/// ## Loading a certificate from your app bundle
/// ```swift
/// guard let url = Bundle.main.url(forResource: "api-example-com", withExtension: "der"),
///       let der = try? Data(contentsOf: url) else { fatalError("missing pinned cert") }
///
/// let policy = CertificatePinningPolicy(["api.example.com": [der]])
/// ```
///
/// ## Chain validation
/// When `validateChain` is `true` (the default), `SecTrustEvaluateWithError` is
/// called first. This confirms that the certificate chain is signed by a trusted
/// root CA and has not expired. Disable it only in controlled environments (e.g.,
/// tests against a local server with a self-signed cert) — never in production.
public struct CertificatePinningPolicy: PinningPolicy {

    // MARK: - Dependencies

    /// Pinned DER-encoded certificate bytes keyed by hostname.
    public let pinnedCertificates: [String: [Data]]

    /// When `true`, the chain is validated via `SecTrustEvaluateWithError` before
    /// comparing certificate bytes. Defaults to `true`.
    public let validateChain: Bool

    // MARK: - Init

    /// Creates a certificate pinning policy.
    ///
    /// - Parameters:
    ///   - map: A dictionary mapping hostnames to arrays of pinned DER-encoded certificate bytes.
    ///   - validateChain: Whether to call `SecTrustEvaluateWithError` before comparing.
    ///     Defaults to `true`. Set to `false` only in test environments.
    public init(_ map: [String: [Data]], validateChain: Bool = true) {
        self.pinnedCertificates = map
        self.validateChain = validateChain
    }

    // MARK: - Implementation

    public func evaluate(serverTrust: SecTrust, host: String) -> PinningResult {
        guard let pinned = pinnedCertificates[host] else { return .notApplicable }

        if validateChain {
            var error: CFError?
            guard SecTrustEvaluateWithError(serverTrust, &error) else { return .reject }
        }

        let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] ?? []
        for cert in chain {
            let serverDER = SecCertificateCopyData(cert) as Data
            if pinned.contains(where: { $0 == serverDER }) {
                return .allow
            }
        }
        return .reject
    }
}
