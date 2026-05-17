import Testing
import Foundation
@testable import ForgeNetworking

// MARK: - Endpoints under test

private struct DownloadImage: DataEndpoint {
    typealias Body = Empty
    var path: String { "/image.png" }
    var method: HTTPMethod { .get }
}

private struct FetchText: StringEndpoint {
    typealias Body = Empty
    var path: String { "/about.txt" }
    var method: HTTPMethod { .get }
}

/// Sanity: existing Decodable endpoint still works.
private struct GetUser: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    let id: Int
    var path: String { "/users/\(id)" }
    var method: HTTPMethod { .get }
}

/// Custom non-Decodable Response with manual decodeResponse.
private struct CountsBytes: Endpoint {
    typealias Body = Empty
    typealias Response = Int
    var path: String { "/blob" }
    var method: HTTPMethod { .get }
    func decodeResponse(from data: Data, response: HTTPResponse, using decoder: JSONDecoder) throws -> Int {
        data.count
    }
}

@Suite("Non-Decodable response types", .serialized)
struct NonDecodableResponseTests {
    private func client(handler: @escaping MockURLProtocol.Handler) -> NetworkClient {
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration(handler: handler)
        return NetworkClient(configuration: config)
    }

    @Test("DataEndpoint returns raw response bytes")
    func dataEndpointReturnsBytes() async throws {
        let payload = Data(repeating: 0xAB, count: 1024)
        let bytes = try await client { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, payload)
        }.send(DownloadImage())
        #expect(bytes == payload)
    }

    @Test("StringEndpoint returns response body as UTF-8 string")
    func stringEndpointReturnsString() async throws {
        let payload = "hello, world"
        let text = try await client { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }.send(FetchText())
        #expect(text == payload)
    }

    @Test("Existing Decodable endpoint still decodes JSON via default extension")
    func decodableStillWorks() async throws {
        let dto = TestPayloadDTO(id: 42, name: "alice")
        let user = try await client { request in
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }.send(GetUser(id: 42))
        #expect(user == dto)
    }

    @Test("Custom non-Decodable endpoint runs its own decodeResponse")
    func customDecodeResponse() async throws {
        let payload = Data(repeating: 0x00, count: 256)
        let count = try await client { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, payload)
        }.send(CountsBytes())
        #expect(count == 256)
    }

    @Test("Empty Response still returns Empty() even with non-empty body")
    func emptyResponseStillEmpty() async throws {
        struct PostEmpty: Endpoint {
            typealias Body = Empty
            typealias Response = Empty
            var path: String { "/x" }
            var method: HTTPMethod { .post }
        }
        _ = try await client { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("ignored".utf8))
        }.send(PostEmpty())
    }
}
