import Testing
import Foundation
import ForgeNetworking
import ForgeNetworkingTesting

private struct EP: Endpoint {
    typealias Body = Empty
    typealias Response = Empty
    var path: String { "/x" }
    var method: HTTPMethod { .get }
}

@Suite("Mock auth helpers")
struct MockAuthProviderTests {
    @Test("MockTokenStore stores and clears")
    func tokenStore() async {
        let store = MockTokenStore()
        await store.set(TokenPair(accessToken: "a", refreshToken: "r"))
        let pair = await store.current()
        #expect(pair?.accessToken == "a")
        await store.clear()
        let cleared = await store.current()
        #expect(cleared == nil)
    }

    @Test("MockAuthProvider applies a fixed token")
    func provider() async throws {
        let provider = MockAuthProvider(token: "abc")
        var req = URLRequest(url: URL(string: "https://x.test")!)
        try await provider.apply(to: &req, endpoint: EP())
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
    }
}
