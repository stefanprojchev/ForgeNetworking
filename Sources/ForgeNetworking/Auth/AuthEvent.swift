public enum AuthEvent: Sendable {
    case refreshed
    case signedOut
    case refreshFailed(any Error & Sendable)
}
