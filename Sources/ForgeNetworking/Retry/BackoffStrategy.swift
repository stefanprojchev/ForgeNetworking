import Foundation

public enum BackoffStrategy: Sendable, Equatable {
    case fixed(TimeInterval)
    case exponentialWithJitter(base: TimeInterval, cap: TimeInterval)

    public func delay(forAttempt attempt: Int) -> TimeInterval {
        switch self {
        case .fixed(let value):
            return value
        case .exponentialWithJitter(let base, let cap):
            let exponent = max(0, attempt - 1)
            let raw = base * pow(2.0, Double(exponent))
            let bounded = min(raw, cap)
            // full jitter in [0, bounded]
            return Double.random(in: 0...bounded)
        }
    }
}
