import Foundation

/// The result of evaluating a server trust challenge against a pinning policy.
public enum PinningResult: Sendable, Equatable {
    /// Pinning passed — accept the connection.
    case allow
    /// Pinning failed — the host is covered by this policy but no pin matched. Cancel the auth challenge.
    case reject
    /// This host is not in the policy map — let URLSession perform its default OS trust evaluation.
    case notApplicable
}

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
