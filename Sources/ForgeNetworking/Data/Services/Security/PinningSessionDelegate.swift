import Foundation

/// A drop-in `URLSessionDelegate` that evaluates server trust challenges
/// using a `PinningPolicy`.
///
/// Wire it into `NetworkConfiguration.sessionDelegate`:
/// ```swift
/// var config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
/// config.sessionDelegate = PinningSessionDelegate(policy: CertificatePinningPolicy([
///     "api.example.com": [pinnedCertificateData],
/// ]))
/// let client = NetworkClient(configuration: config)
/// ```
///
/// Challenge routing:
/// - Non–server-trust challenges (HTTP Basic, client certificates, etc.) fall through
///   to `.performDefaultHandling` — this delegate only intercepts TLS server trust.
/// - `.allow` → `.useCredential(URLCredential(trust:))`
/// - `.reject` → `.cancelAuthenticationChallenge`
/// - `.notApplicable` → `.performDefaultHandling` (OS default trust evaluation)
///
/// To add other delegate behavior alongside pinning (redirect handling, metrics, etc.),
/// subclass `PinningSessionDelegate` or compose your own `URLSessionDelegate` that
/// calls into a `PinningPolicy` directly.
///
/// ## Sendable note
/// Marked `@unchecked Sendable` because `NSObject` doesn't carry `Sendable` automatically.
/// The stored `policy` is itself `Sendable`; the class has no mutable state.
public final class PinningSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {

    // MARK: - Dependencies

    /// The policy used to evaluate each server trust challenge.
    public let policy: any PinningPolicy

    // MARK: - Init

    /// Creates a delegate backed by the given pinning policy.
    ///
    /// - Parameter policy: The policy that decides whether to allow, reject,
    ///   or defer each server trust challenge.
    public init(policy: any PinningPolicy) {
        self.policy = policy
    }

    // MARK: - Implementation

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host
        switch policy.evaluate(serverTrust: serverTrust, host: host) {
        case .allow:
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        case .reject:
            completionHandler(.cancelAuthenticationChallenge, nil)
        case .notApplicable:
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
