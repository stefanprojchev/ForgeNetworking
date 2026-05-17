import Foundation
import ForgeCrypt
import ForgeNetworking

/// `TokenStore` backed by any `CryptStoring` implementation. In production use
/// `CryptStore` (keychain); in tests use `InMemoryCrypt`. The token is serialized
/// as a single `TokenPair` value under a caller-supplied key name.
public actor KeychainTokenStore: TokenStore {

    // MARK: - Dependencies

    private let backing: any CryptStoring
    private let key: CryptKey<TokenPair>

    // MARK: - Init

    public init(
        backing: any CryptStoring,
        keyName: String = "forge-networking.token-pair",
        accessibility: CryptAccessibility = .afterFirstUnlock
    ) {
        self.backing = backing
        self.key = CryptKey<TokenPair>(key: keyName, accessibility: accessibility)
    }

    // MARK: - Implementation

    public func current() -> TokenPair? {
        (try? backing.get(key)) ?? nil
    }

    public func set(_ pair: TokenPair?) {
        if let pair {
            try? backing.set(pair, for: key)
        } else {
            try? backing.delete(key)
        }
    }
}
