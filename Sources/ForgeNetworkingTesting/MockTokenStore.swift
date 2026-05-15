import Foundation
import ForgeNetworking

public actor MockTokenStore: TokenStore {
    private var pair: TokenPair?
    public init(initial: TokenPair? = nil) { self.pair = initial }
    public func current() -> TokenPair? { pair }
    public func set(_ pair: TokenPair?) { self.pair = pair }
}
