import Testing
import Foundation
@testable import ForgeNetworking

@Suite("RequestBuilder")
struct RequestBuilderTests {
    private struct GetItem: Endpoint {
        typealias Body = Empty
        typealias Response = TestPayloadDTO
        var path: String { "/items/42" }
        var method: HTTPMethod { .get }
        var queryItems: [URLQueryItem] { [URLQueryItem(name: "include", value: "owner")] }
        var headers: [String: String] { ["X-Trace": "abc"] }
    }

    private struct CreateItem: Endpoint {
        typealias Body = TestPayloadDTO
        typealias Response = TestPayloadDTO
        var path: String { "/items" }
        var method: HTTPMethod { .post }
        var body: RequestBody<TestPayloadDTO> {
            .json(TestPayloadDTO(id: 1, name: "x"))
        }
    }

    @Test("Builds GET URLRequest with query items and headers")
    func buildsGet() throws {
        let req = try RequestBuilder.build(
            endpoint: GetItem(),
            baseURL: URL(string: "https://api.example.com")!,
            defaultHeaders: ["Accept": "application/json"],
            encoder: JSONEncoder()
        ).request

        #expect(req.url?.absoluteString == "https://api.example.com/items/42?include=owner")
        #expect(req.httpMethod == "GET")
        #expect(req.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(req.value(forHTTPHeaderField: "X-Trace") == "abc")
    }

    @Test("POST body sets httpBody and content-type")
    func buildsPost() throws {
        let built = try RequestBuilder.build(
            endpoint: CreateItem(),
            baseURL: URL(string: "https://api.example.com")!,
            defaultHeaders: [:],
            encoder: JSONEncoder()
        )

        #expect(built.request.httpMethod == "POST")
        #expect(built.request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(built.request.httpBody != nil)
    }

    @Test("Endpoint headers override defaults on conflict")
    func endpointHeaderOverridesDefault() throws {
        struct EP: Endpoint {
            typealias Body = Empty
            typealias Response = Empty
            var path: String { "/x" }
            var method: HTTPMethod { .get }
            var headers: [String: String] { ["Accept": "text/plain"] }
        }
        let req = try RequestBuilder.build(
            endpoint: EP(),
            baseURL: URL(string: "https://x.test")!,
            defaultHeaders: ["Accept": "application/json"],
            encoder: JSONEncoder()
        ).request
        #expect(req.value(forHTTPHeaderField: "Accept") == "text/plain")
    }
}
