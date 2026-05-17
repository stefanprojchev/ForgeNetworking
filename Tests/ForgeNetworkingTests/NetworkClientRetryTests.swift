import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

private struct GetItem: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/items/1" }
    var method: HTTPMethod { .get }
}

@Suite("NetworkClient retry", .serialized)
struct NetworkClientRetryTests {
    @Test("Retries 503 then succeeds")
    func retriesThenSucceeds() async throws {
        let count = LockedState(0)
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            let n = count.withLock { $0 += 1; return $0 }
            if n < 2 {
                return (HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
            }
            let data = try JSONEncoder().encode(TestPayloadDTO(id: 1, name: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        config.retryPolicy = RetryPolicy(maxAttempts: 3, backoff: .fixed(0.01))

        let client = NetworkClient(configuration: config)
        let dto = try await client.send(GetItem())
        #expect(dto.name == "ok")
        #expect(count.withLock { $0 } == 2)
    }

    @Test("Exhausts attempts and throws .retryExhausted")
    func exhausts() async throws {
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            (HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
        }
        config.retryPolicy = RetryPolicy(maxAttempts: 2, backoff: .fixed(0.01))

        let client = NetworkClient(configuration: config)
        do {
            _ = try await client.send(GetItem())
            Issue.record("expected throw")
        } catch let NetworkError.retryExhausted(last) {
            if case .serverError = last {} else { Issue.record("expected serverError as last") }
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test("Honors Retry-After header (0 seconds) and retries immediately")
    func honorsRetryAfter() async throws {
        let count = LockedState(0)
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            let n = count.withLock { $0 += 1; return $0 }
            if n == 1 {
                return (HTTPURLResponse(
                    url: request.url!, statusCode: 503, httpVersion: nil,
                    headerFields: ["Retry-After": "0"]
                )!, Data())
            }
            let data = try JSONEncoder().encode(TestPayloadDTO(id: 1, name: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        config.retryPolicy = RetryPolicy(maxAttempts: 3, backoff: .fixed(60))  // long backoff
        // Retry-After: 0 should override the long backoff.

        let client = NetworkClient(configuration: config)
        let start = Date()
        _ = try await client.send(GetItem())
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 5)
    }
}
