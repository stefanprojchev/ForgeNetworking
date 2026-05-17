import Foundation
import Security

/// A type that evaluates server trust challenges for TLS pinning.
///
/// Implement this protocol to provide custom pinning logic, or use the built-in
/// `CertificatePinningPolicy` and `PublicKeyPinningPolicy`.
///
/// The three-valued result allows policies to be composed: a policy that returns
/// `.notApplicable` for hosts it doesn't know about lets the OS's default
/// certificate validation run for those hosts, rather than unconditionally
/// blocking or accepting them.
public protocol PinningPolicy: Sendable {
    /// Evaluate a server trust challenge.
    ///
    /// - Parameters:
    ///   - serverTrust: The `SecTrust` object from the authentication challenge.
    ///   - host: The hostname from the challenge's protection space.
    /// - Returns: `.allow` to accept the connection, `.reject` to cancel the auth
    ///   challenge, or `.notApplicable` if this policy doesn't cover the host (allows
    ///   fallback to default OS trust evaluation).
    func evaluate(serverTrust: SecTrust, host: String) -> PinningResult
}
