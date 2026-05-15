import Testing
import Foundation
@testable import ForgeNetworking

private struct EP: Endpoint {
    typealias Body = Empty
    typealias Response = Empty
    var path: String { "/x" }
    var method: HTTPMethod { .get }
}

@Suite("BasicAuthProvider")
struct BasicAuthProviderTests {
    @Test("Adds Base64-encoded Authorization header")
    func addsAuthHeader() async throws {
        let provider = BasicAuthProvider(username: "alice", password: "p4ssw0rd")
        var req = URLRequest(url: URL(string: "https://x.test")!)
        try await provider.apply(to: &req, endpoint: EP())

        let expected = Data("alice:p4ssw0rd".utf8).base64EncodedString()
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Basic \(expected)")
    }
}
