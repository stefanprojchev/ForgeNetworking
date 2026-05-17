import Foundation

public struct RetryPolicy: Sendable, Equatable {
    public var maxAttempts: Int
    public var backoff: BackoffStrategy
    public var retryableStatuses: Set<Int>
    public var retryableMethods: Set<HTTPMethod>
    public var honorsRetryAfter: Bool
    /// Optional wall-clock cap for the total `send(_:)` duration (all attempts + backoff waits).
    /// When set, the retry loop checks elapsed time before each backoff sleep — if the next
    /// backoff would push past `deadline`, the call fails immediately with `.retryExhausted`.
    /// `nil` (default) preserves the existing behaviour.
    public var deadline: TimeInterval?
    public var shouldRetry: (@Sendable (NetworkError, Int) -> Bool)?

    public init(
        maxAttempts: Int = 3,
        backoff: BackoffStrategy = .exponentialWithJitter(base: 0.5, cap: 8),
        retryableStatuses: Set<Int> = [408, 425, 429, 500, 502, 503, 504],
        retryableMethods: Set<HTTPMethod> = [.get, .head, .put, .delete, .options],
        honorsRetryAfter: Bool = true,
        deadline: TimeInterval? = nil,
        shouldRetry: (@Sendable (NetworkError, Int) -> Bool)? = nil
    ) {
        self.maxAttempts = maxAttempts
        self.backoff = backoff
        self.retryableStatuses = retryableStatuses
        self.retryableMethods = retryableMethods
        self.honorsRetryAfter = honorsRetryAfter
        self.deadline = deadline
        self.shouldRetry = shouldRetry
    }

    public static let `default` = RetryPolicy()

    public static func == (lhs: RetryPolicy, rhs: RetryPolicy) -> Bool {
        lhs.maxAttempts == rhs.maxAttempts &&
        lhs.backoff == rhs.backoff &&
        lhs.retryableStatuses == rhs.retryableStatuses &&
        lhs.retryableMethods == rhs.retryableMethods &&
        lhs.honorsRetryAfter == rhs.honorsRetryAfter &&
        lhs.deadline == rhs.deadline
        // closures intentionally not compared
    }

    public func shouldRetry(error: NetworkError, method: HTTPMethod, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        if let custom = shouldRetry { return custom(error, attempt) }
        guard retryableMethods.contains(method) else { return false }
        switch error {
        case .transport, .timeout:
            return true
        case .serverError(let response, _), .clientError(let response, _):
            return retryableStatuses.contains(response.statusCode)
        default:
            return false
        }
    }
}
