import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

private struct EP: Endpoint {
    typealias Body = Empty
    typealias Response = Empty
    var path: String { "/x" }
    var method: HTTPMethod { .get }
}

// MARK: - Custom TokenStore for test 4

private actor RecordingTokenStore: TokenStore {
    private(set) var setCalls: [TokenPair?] = []
    private var current_: TokenPair?

    init(initial: TokenPair? = nil) {
        current_ = initial
    }

    func current() -> TokenPair? { current_ }

    func set(_ pair: TokenPair?) {
        setCalls.append(pair)
        current_ = pair
    }
}

@Suite("Auth advanced")
struct AuthAdvancedTests {

    // MARK: 1 — BearerAuthProvider with custom scheme and header

    @Test("BearerAuthProvider with custom scheme and header uses correct field")
    func customSchemeAndHeader() async throws {
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "abc", refreshToken: "r"))
        let coord = RefreshCoordinator { _ in TokenPair(accessToken: "x", refreshToken: "y") }
        let provider = BearerAuthProvider(
            store: store,
            coordinator: coord,
            headerName: "X-Auth",
            scheme: "Token"
        )

        var req = URLRequest(url: URL(string: "https://x.test")!)
        try await provider.apply(to: &req, endpoint: EP())

        #expect(req.value(forHTTPHeaderField: "X-Auth") == "Token abc")
        #expect(req.value(forHTTPHeaderField: "Authorization") == nil)
    }

    // MARK: 2 — APIKeyAuthProvider query placement preserves existing items

    @Test("APIKeyAuthProvider query placement preserves existing query items")
    func apiKeyQueryPreservesExistingItems() async throws {
        let provider = APIKeyAuthProvider(key: "abc", placement: .query(name: "api_key"))

        var req = URLRequest(url: URL(string: "https://x.test/items?foo=1&bar=2")!)
        try await provider.apply(to: &req, endpoint: EP())

        let urlString = req.url?.absoluteString ?? ""
        #expect(urlString.contains("foo=1"))
        #expect(urlString.contains("bar=2"))
        #expect(urlString.contains("api_key=abc"))
    }

    // MARK: 3 — RefreshCoordinator subsequent refresh after first success

    @Test("RefreshCoordinator calls refresh closure again after successful prior call")
    func subsequentRefreshWorks() async throws {
        let callCount = LockedState(0)
        let coordinator = RefreshCoordinator { _ in
            callCount.withLock { $0 += 1 }
            return TokenPair(accessToken: "new\(callCount.withLock { $0 })", refreshToken: "r")
        }
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "old", refreshToken: "r"))

        let pair1 = try await coordinator.refresh(using: store)
        #expect(pair1.accessToken == "new1")

        // Re-seed the store so the second call has something to refresh with
        await store.set(TokenPair(accessToken: "new1", refreshToken: "r2"))
        let pair2 = try await coordinator.refresh(using: store)
        #expect(pair2.accessToken == "new2")

        #expect(callCount.withLock { $0 } == 2)
    }

    // MARK: 4 — TokenStore.clear() default extension calls set(nil)

    @Test("TokenStore.clear() default extension calls set with nil")
    func clearCallsSetNil() async {
        let store = RecordingTokenStore(initial: TokenPair(accessToken: "t", refreshToken: "r"))
        await store.clear()
        let calls = await store.setCalls
        #expect(calls.count == 1)
        #expect(calls.first! == nil)
    }
}
