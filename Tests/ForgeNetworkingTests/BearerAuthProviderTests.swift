import Testing
import Foundation
@testable import ForgeNetworking

private struct EP: Endpoint {
    typealias Body = Empty
    typealias Response = Empty
    var path: String { "/x" }
    var method: HTTPMethod { .get }
}

@Suite("BearerAuthProvider")
struct BearerAuthProviderTests {
    @Test("Adds bearer header when token is present")
    func addsHeader() async throws {
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "abc", refreshToken: "xyz"))
        let coord = RefreshCoordinator { _ in TokenPair(accessToken: "new", refreshToken: "newR") }
        let provider = BearerAuthProvider(store: store, coordinator: coord)

        var req = URLRequest(url: URL(string: "https://x.test")!)
        try await provider.apply(to: &req, endpoint: EP())
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
    }

    @Test("Does not add header when no token is present")
    func noToken() async throws {
        let store = InMemoryTokenStore()
        let coord = RefreshCoordinator { _ in TokenPair(accessToken: "x", refreshToken: "y") }
        let provider = BearerAuthProvider(store: store, coordinator: coord)

        var req = URLRequest(url: URL(string: "https://x.test")!)
        try await provider.apply(to: &req, endpoint: EP())
        #expect(req.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("handle(unauthorized:) refreshes and returns .retry on success")
    func refreshSucceeds() async throws {
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "old", refreshToken: "r"))
        let coord = RefreshCoordinator { _ in TokenPair(accessToken: "new", refreshToken: "r2") }
        let provider = BearerAuthProvider(store: store, coordinator: coord)

        let response = HTTPResponse(
            statusCode: 401,
            headers: [:],
            body: Data(),
            request: URLRequest(url: URL(string: "https://x.test")!)
        )
        let recovery = try await provider.handle(unauthorized: response)
        if case .retry = recovery {} else { Issue.record("expected .retry") }
        let stored = await store.current()
        #expect(stored?.accessToken == "new")
    }

    @Test("handle(unauthorized:) returns .fail when refresh throws")
    func refreshFails() async throws {
        struct Boom: Error {}
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "old", refreshToken: "r"))
        let coord = RefreshCoordinator { _ -> TokenPair in throw Boom() }
        let provider = BearerAuthProvider(store: store, coordinator: coord)

        let response = HTTPResponse(
            statusCode: 401,
            headers: [:],
            body: Data(),
            request: URLRequest(url: URL(string: "https://x.test")!)
        )
        let recovery = try await provider.handle(unauthorized: response)
        if case .fail = recovery {} else { Issue.record("expected .fail") }
    }
}
