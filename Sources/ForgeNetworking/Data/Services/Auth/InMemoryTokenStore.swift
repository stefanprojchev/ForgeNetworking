import Foundation

public actor InMemoryTokenStore: TokenStore {

    // MARK: - Dependencies

    private var pair: TokenPair?

    // MARK: - Init

    public init(initial: TokenPair? = nil) { self.pair = initial }

    // MARK: - Implementation

    public func current() -> TokenPair? { pair }
    public func set(_ pair: TokenPair?) { self.pair = pair }
}
