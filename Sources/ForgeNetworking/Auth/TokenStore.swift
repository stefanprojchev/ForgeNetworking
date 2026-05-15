import Foundation

public protocol TokenStore: Sendable {
    func current() async -> TokenPair?
    func set(_ pair: TokenPair?) async
    func clear() async
}

public extension TokenStore {
    func clear() async { await set(nil) }
}

public actor InMemoryTokenStore: TokenStore {
    private var pair: TokenPair?

    public init(initial: TokenPair? = nil) { self.pair = initial }

    public func current() -> TokenPair? { pair }
    public func set(_ pair: TokenPair?) { self.pair = pair }
}
