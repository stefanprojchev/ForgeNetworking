import Foundation

public protocol TokenStore: Sendable {
    func current() async -> TokenPair?
    func set(_ pair: TokenPair?) async
    func clear() async
}

public extension TokenStore {
    func clear() async { await set(nil) }
}
