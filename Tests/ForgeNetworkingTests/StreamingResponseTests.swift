import Testing
import Foundation
@testable import ForgeNetworking

private struct StreamEndpoint: Endpoint {
    typealias Body = Empty
    typealias Response = Empty
    var path: String { "/stream" }
    var method: HTTPMethod { .get }
}

@Suite("Streaming response", .serialized)
struct StreamingResponseTests {
    @Test("stream(_:) returns response and an AsyncThrowingStream that delivers all bytes")
    func deliversAllBytes() async throws {
        let payload = Data("hello world".utf8)
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, payload)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        let client = NetworkClient(configuration: config)

        let (response, stream) = try await client.stream(StreamEndpoint())
        #expect(response.statusCode == 200)

        var collected = Data()
        for try await chunk in stream {
            collected.append(chunk)
        }
        #expect(collected == payload)
    }

    @Test("stream(_:) emits chunks (one or more) and finishes cleanly")
    func emitsChunks() async throws {
        let payload = Data(repeating: 0xAB, count: 16 * 1024)
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, payload)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        let client = NetworkClient(configuration: config)

        let (_, stream) = try await client.stream(StreamEndpoint())
        var chunkCount = 0
        var totalBytes = 0
        for try await chunk in stream {
            chunkCount += 1
            totalBytes += chunk.count
        }
        #expect(chunkCount >= 1)
        #expect(totalBytes == payload.count)
    }
}
