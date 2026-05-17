/// The result of evaluating a server trust challenge against a pinning policy.
public enum PinningResult: Sendable, Equatable {
    /// Pinning passed — accept the connection.
    case allow
    /// Pinning failed — the host is covered by this policy but no pin matched. Cancel the auth challenge.
    case reject
    /// This host is not in the policy map — let URLSession perform its default OS trust evaluation.
    case notApplicable
}
