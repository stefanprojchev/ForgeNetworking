import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

private struct PostOrder: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/orders" }
    var method: HTTPMethod { .post }
    var idempotencyKeyEnabled: Bool { true }
}

private struct PostOrderCustomHeader: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/orders" }
    var method: HTTPMethod { .post }
    var idempotencyKeyEnabled: Bool { true }
    var idempotencyKeyHeaderName: String { "X-Idempotency-Key" }
}

private struct PostWithoutIdempotency: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/orders" }
    var method: HTTPMethod { .post }
    // idempotencyKeyEnabled defaults to false
}

@Suite("Idempotency-Key auto-injection")
struct IdempotencyKeyTests {
    @Test("Endpoint with idempotencyKeyEnabled sends Idempotency-Key header")
    func sendsHeader() async throws {
        let observedKey = LockedState<String?>(nil)
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            observedKey.withLock { $0 = request.value(forHTTPHeaderField: "Idempotency-Key") }
            let dto = TestPayloadDTO(id: 1, name: "ok")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = NetworkClient(configuration: config)
        _ = try await client.send(PostOrder())

        let key = observedKey.withLock { $0 }
        #expect(key != nil)
        #expect(UUID(uuidString: key!) != nil, "key should be a UUID")
    }

    @Test("Endpoint without idempotencyKeyEnabled does NOT send the header")
    func noHeaderWhenDisabled() async throws {
        let observedKey = LockedState<String?>(nil)
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            observedKey.withLock { $0 = request.value(forHTTPHeaderField: "Idempotency-Key") }
            let dto = TestPayloadDTO(id: 1, name: "ok")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = NetworkClient(configuration: config)
        _ = try await client.send(PostWithoutIdempotency())

        let key = observedKey.withLock { $0 }
        #expect(key == nil)
    }

    @Test("Custom header name is honored")
    func customHeaderName() async throws {
        let observedDefault = LockedState<String?>(nil)
        let observedCustom = LockedState<String?>(nil)
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            observedDefault.withLock { $0 = request.value(forHTTPHeaderField: "Idempotency-Key") }
            observedCustom.withLock { $0 = request.value(forHTTPHeaderField: "X-Idempotency-Key") }
            let dto = TestPayloadDTO(id: 1, name: "ok")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = NetworkClient(configuration: config)
        _ = try await client.send(PostOrderCustomHeader())

        #expect(observedDefault.withLock { $0 } == nil)
        #expect(observedCustom.withLock { $0 } != nil)
    }

    @Test("Retried request reuses the same idempotency key")
    func sameKeyAcrossRetries() async throws {
        let observedKeys = LockedState<[String]>([])
        let callCount = LockedState(0)
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            if let key = request.value(forHTTPHeaderField: "Idempotency-Key") {
                observedKeys.withLock { $0.append(key) }
            }
            let n = callCount.withLock { $0 += 1; return $0 }
            if n < 3 {
                // Force retries: 503 (in default retryable statuses)
                return (HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
            }
            let dto = TestPayloadDTO(id: 1, name: "ok")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        // Force POST to be retryable by including it in retryableMethods
        config.retryPolicy = RetryPolicy(
            maxAttempts: 4,
            backoff: .fixed(0.001),
            retryableMethods: [.post]
        )
        let client = NetworkClient(configuration: config)
        _ = try await client.send(PostOrder())

        let keys = observedKeys.withLock { $0 }
        #expect(keys.count == 3, "should have observed 3 requests with the header")
        #expect(Set(keys).count == 1, "all retries should share the same UUID")
    }

    @Test("Different send calls get different keys")
    func differentSendsDifferentKeys() async throws {
        let observedKeys = LockedState<[String]>([])
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            if let key = request.value(forHTTPHeaderField: "Idempotency-Key") {
                observedKeys.withLock { $0.append(key) }
            }
            let dto = TestPayloadDTO(id: 1, name: "ok")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = NetworkClient(configuration: config)
        _ = try await client.send(PostOrder())
        _ = try await client.send(PostOrder())
        _ = try await client.send(PostOrder())

        let keys = observedKeys.withLock { $0 }
        #expect(keys.count == 3)
        #expect(Set(keys).count == 3, "each send should generate a fresh key")
    }
}
