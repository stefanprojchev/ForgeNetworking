import Testing
import Foundation
@testable import ForgeNetworking

private struct EP: Endpoint {
    typealias Body = Empty
    typealias Response = Empty
    var path: String { "/x" }
    var method: HTTPMethod { .get }
}

@Suite("APIKeyAuthProvider")
struct APIKeyAuthProviderTests {
    @Test("Header placement injects header")
    func headerPlacement() async throws {
        let provider = APIKeyAuthProvider(key: "abc", placement: .header(name: "X-API-Key"))
        var req = URLRequest(url: URL(string: "https://x.test/items")!)
        try await provider.apply(to: &req, endpoint: EP())
        #expect(req.value(forHTTPHeaderField: "X-API-Key") == "abc")
    }

    @Test("Query placement appends URL query item")
    func queryPlacement() async throws {
        let provider = APIKeyAuthProvider(key: "abc", placement: .query(name: "api_key"))
        var req = URLRequest(url: URL(string: "https://x.test/items?foo=1")!)
        try await provider.apply(to: &req, endpoint: EP())
        let urlString = req.url?.absoluteString ?? ""
        #expect(urlString.contains("foo=1"))
        #expect(urlString.contains("api_key=abc"))
    }
}
