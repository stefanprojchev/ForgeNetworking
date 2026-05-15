import Foundation

public enum RetryExecutor {
    /// Computes the delay for the next attempt, optionally overridden by Retry-After.
    public static func delay(
        for error: NetworkError,
        attempt: Int,
        policy: RetryPolicy
    ) -> TimeInterval {
        if policy.honorsRetryAfter {
            switch error {
            case .clientError(let response, _), .serverError(let response, _):
                if let header = response.value(forHeader: "Retry-After"),
                   let seconds = RetryAfterParser.parse(header) {
                    return seconds
                }
            default: break
            }
        }
        return policy.backoff.delay(forAttempt: attempt)
    }
}
