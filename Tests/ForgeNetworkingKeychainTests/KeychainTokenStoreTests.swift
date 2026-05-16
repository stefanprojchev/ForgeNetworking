import Testing
import Foundation
import ForgeCrypt
import ForgeNetworking
import ForgeNetworkingKeychain

@Suite("KeychainTokenStore")
struct KeychainTokenStoreTests {
    @Test("Round-trips a TokenPair through the underlying CryptStoring")
    func roundTrip() async throws {
        let backing = InMemoryCrypt()
        let store = KeychainTokenStore(backing: backing, keyName: "test-token")

        let pair = TokenPair(accessToken: "access", refreshToken: "refresh")
        await store.set(pair)

        let read = await store.current()
        #expect(read?.accessToken == "access")
        #expect(read?.refreshToken == "refresh")
    }

    @Test("Returns nil when no token has been stored")
    func emptyStoreReturnsNil() async {
        let backing = InMemoryCrypt()
        let store = KeychainTokenStore(backing: backing, keyName: "test-token")
        let read = await store.current()
        #expect(read == nil)
    }

    @Test("clear() removes the stored token")
    func clearRemoves() async {
        let backing = InMemoryCrypt()
        let store = KeychainTokenStore(backing: backing, keyName: "test-token")
        await store.set(TokenPair(accessToken: "a", refreshToken: "r"))
        await store.clear()
        let read = await store.current()
        #expect(read == nil)
    }

    @Test("expiresAt persists across a round trip")
    func expiresAtRoundTrip() async throws {
        let backing = InMemoryCrypt()
        let store = KeychainTokenStore(backing: backing, keyName: "test-token")
        let exp = Date(timeIntervalSince1970: 1_700_000_000)
        await store.set(TokenPair(accessToken: "a", refreshToken: "r", expiresAt: exp))
        let read = await store.current()
        #expect(read?.expiresAt == exp)
    }
}
