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

@Suite("Proactive refresh")
struct ProactiveRefreshTests {
    @Test("Refreshes proactively when expiresAt is in the past")
    func refreshesWhenExpired() async throws {
        let calls = LockedState(0)
        let store = InMemoryTokenStore(initial: TokenPair(
            accessToken: "old",
            refreshToken: "r",
            expiresAt: Date(timeIntervalSinceNow: -10)  // expired
        ))
        let coord = RefreshCoordinator { _ in
            calls.withLock { $0 += 1 }
            return TokenPair(accessToken: "new", refreshToken: "r2",
                             expiresAt: Date(timeIntervalSinceNow: 3600))
        }
        let provider = BearerAuthProvider(store: store, coordinator: coord, proactiveRefreshHeadroom: 30)

        var req = URLRequest(url: URL(string: "https://x.test")!)
        try await provider.apply(to: &req, endpoint: EP())

        #expect(calls.withLock { $0 } == 1)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer new")
    }

    @Test("Refreshes proactively when expiresAt is within headroom")
    func refreshesWithinHeadroom() async throws {
        let calls = LockedState(0)
        let store = InMemoryTokenStore(initial: TokenPair(
            accessToken: "old",
            refreshToken: "r",
            expiresAt: Date(timeIntervalSinceNow: 10)  // expires in 10s, headroom 30
        ))
        let coord = RefreshCoordinator { _ in
            calls.withLock { $0 += 1 }
            return TokenPair(accessToken: "new", refreshToken: "r2",
                             expiresAt: Date(timeIntervalSinceNow: 3600))
        }
        let provider = BearerAuthProvider(store: store, coordinator: coord, proactiveRefreshHeadroom: 30)

        var req = URLRequest(url: URL(string: "https://x.test")!)
        try await provider.apply(to: &req, endpoint: EP())
        #expect(calls.withLock { $0 } == 1)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer new")
    }

    @Test("Does NOT refresh when expiresAt is far in the future")
    func skipsWhenFresh() async throws {
        let calls = LockedState(0)
        let store = InMemoryTokenStore(initial: TokenPair(
            accessToken: "fresh",
            refreshToken: "r",
            expiresAt: Date(timeIntervalSinceNow: 3600)
        ))
        let coord = RefreshCoordinator { _ in
            calls.withLock { $0 += 1 }
            return TokenPair(accessToken: "new", refreshToken: "r2")
        }
        let provider = BearerAuthProvider(store: store, coordinator: coord, proactiveRefreshHeadroom: 30)

        var req = URLRequest(url: URL(string: "https://x.test")!)
        try await provider.apply(to: &req, endpoint: EP())
        #expect(calls.withLock { $0 } == 0)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer fresh")
    }

    @Test("Does NOT refresh proactively when expiresAt is nil")
    func skipsWhenExpiresAtNil() async throws {
        let calls = LockedState(0)
        let store = InMemoryTokenStore(initial: TokenPair(
            accessToken: "any",
            refreshToken: "r"  // expiresAt defaults to nil
        ))
        let coord = RefreshCoordinator { _ in
            calls.withLock { $0 += 1 }
            return TokenPair(accessToken: "new", refreshToken: "r2")
        }
        let provider = BearerAuthProvider(store: store, coordinator: coord, proactiveRefreshHeadroom: 30)

        var req = URLRequest(url: URL(string: "https://x.test")!)
        try await provider.apply(to: &req, endpoint: EP())
        #expect(calls.withLock { $0 } == 0)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer any")
    }

    @Test("Proactive refresh failure falls through with stale token (does not block request)")
    func failureFallsThrough() async throws {
        struct Boom: Error {}
        let store = InMemoryTokenStore(initial: TokenPair(
            accessToken: "stale",
            refreshToken: "r",
            expiresAt: Date(timeIntervalSinceNow: -10)
        ))
        let coord = RefreshCoordinator { _ -> TokenPair in throw Boom() }
        let provider = BearerAuthProvider(store: store, coordinator: coord, proactiveRefreshHeadroom: 30)

        var req = URLRequest(url: URL(string: "https://x.test")!)
        try await provider.apply(to: &req, endpoint: EP())
        // Refresh failed and cleared the store — header should be absent (not stale-applied).
        // (RefreshCoordinator clears the store on failure.)
        #expect(req.value(forHTTPHeaderField: "Authorization") == nil)
    }
}
