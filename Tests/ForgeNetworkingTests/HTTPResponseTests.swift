import Testing
import Foundation
@testable import ForgeNetworking

@Suite("HTTPResponse")
struct HTTPResponseTests {
    @Test("Stores status, headers, body, and originating request")
    func storesFields() {
        let url = URL(string: "https://api.example.com/users/1")!
        let request = URLRequest(url: url)
        let body = Data("hello".utf8)
        let response = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: body,
            request: request
        )

        #expect(response.statusCode == 200)
        #expect(response.headers["Content-Type"] == "application/json")
        #expect(response.body == body)
        #expect(response.request.url == url)
    }

    @Test("Header lookup is case-insensitive")
    func caseInsensitiveHeaders() {
        let response = HTTPResponse(
            statusCode: 200,
            headers: ["content-type": "application/json"],
            body: Data(),
            request: URLRequest(url: URL(string: "https://x.test")!)
        )
        #expect(response.value(forHeader: "Content-Type") == "application/json")
        #expect(response.value(forHeader: "CONTENT-TYPE") == "application/json")
    }

    @Test("Empty is encodable as JSON object")
    func emptyEncodesToObject() throws {
        let data = try JSONEncoder().encode(Empty())
        #expect(String(data: data, encoding: .utf8) == "{}")
    }
}
