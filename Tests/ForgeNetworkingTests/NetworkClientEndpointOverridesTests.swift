import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking
import ForgeNetworkingTesting

// MARK: - Private endpoint stubs

private struct NoAuthItem: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/no-auth" }
    var method: HTTPMethod { .get }
    var authentication: AuthenticationMode { .none }
}

private struct OverrideAuthItem: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/override-auth" }
    var method: HTTPMethod { .get }
    let overrideToken: String
    var authentication: AuthenticationMode { .override(MockAuthProvider(token: overrideToken)) }
}

private struct PerEndpointRetryItem: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/retry-heavy" }
    var method: HTTPMethod { .get }
    var retryPolicy: RetryPolicy? {
        RetryPolicy(maxAttempts: 5, backoff: .fixed(0.001))
    }
}

private struct ShortTimeoutItem: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/slow" }
    var method: HTTPMethod { .get }
    var timeout: TimeInterval? { 0.05 }
}

// MARK: - Suite

@Suite("NetworkClient endpoint overrides", .serialized)
struct NetworkClientEndpointOverridesTests {

    // MARK: - Test A: authentication == .none skips auth provider

    @Test("authentication == .none skips the configured auth provider")
    func noneSkipsAuthProvider() async throws {
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "secret", refreshToken: "r"))
        let coord = RefreshCoordinator { _ in TokenPair(accessToken: "n", refreshToken: "n") }
        let provider = BearerAuthProvider(store: store, coordinator: coord)

        let authHeaderSeen = LockedState<String?>(nil)
        MockURLProtocol.handler = { request in
            authHeaderSeen.withLock { $0 = request.value(forHTTPHeaderField: "Authorization") }
            let data = try JSONEncoder().encode(TestPayloadDTO(id: 1, name: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.authProvider = provider

        let client = NetworkClient(configuration: config)
        _ = try await client.send(NoAuthItem())

        let header = authHeaderSeen.withLock { $0 }
        #expect(header == nil, "Expected no Authorization header when authentication == .none, got: \(header ?? "nil")")
    }

    // MARK: - Test B: authentication == .override uses supplied provider

    @Test("authentication == .override uses the supplied provider instead of client default")
    func overrideAuthProvider() async throws {
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "main", refreshToken: "r"))
        let coord = RefreshCoordinator { _ in TokenPair(accessToken: "n", refreshToken: "n") }
        let mainProvider = BearerAuthProvider(store: store, coordinator: coord)

        let authHeaderSeen = LockedState<String?>(nil)
        MockURLProtocol.handler = { request in
            authHeaderSeen.withLock { $0 = request.value(forHTTPHeaderField: "Authorization") }
            let data = try JSONEncoder().encode(TestPayloadDTO(id: 1, name: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.authProvider = mainProvider

        let client = NetworkClient(configuration: config)
        _ = try await client.send(OverrideAuthItem(overrideToken: "override"))

        let header = authHeaderSeen.withLock { $0 }
        #expect(header == "Bearer override", "Expected 'Bearer override', got: \(header ?? "nil")")
    }

    // MARK: - Test C: Per-endpoint retryPolicy overrides client default

    @Test("Per-endpoint retryPolicy overrides client default")
    func perEndpointRetryPolicy() async throws {
        let requestCount = LockedState(0)
        MockURLProtocol.handler = { request in
            let n = requestCount.withLock { $0 += 1; return $0 }
            if n < 5 {
                return (HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
            }
            let data = try JSONEncoder().encode(TestPayloadDTO(id: 1, name: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        // Client default allows only 1 attempt — endpoint overrides to 5
        config.retryPolicy = RetryPolicy(maxAttempts: 1)

        let client = NetworkClient(configuration: config)
        let result = try await client.send(PerEndpointRetryItem())
        #expect(result.name == "ok")
        #expect(requestCount.withLock { $0 } == 5)
    }

    // MARK: - Test D: Per-endpoint timeout overrides client default

    @Test("Per-endpoint timeout overrides client default and triggers .timeout")
    func perEndpointTimeout() async throws {
        MockURLProtocol.handler = { request in
            // Delay longer than the endpoint's 50ms timeout
            Thread.sleep(forTimeInterval: 0.5)
            let data = try JSONEncoder().encode(TestPayloadDTO(id: 1, name: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.timeout = 60           // client default: very long
        config.retryPolicy = RetryPolicy(maxAttempts: 1)

        let client = NetworkClient(configuration: config)

        do {
            _ = try await client.send(ShortTimeoutItem())
            Issue.record("Expected timeout error but got success")
        } catch let error as NetworkError {
            // The timeout is retryable by default, so with maxAttempts=1 it is wrapped in retryExhausted.
            // Accept either bare .timeout or .retryExhausted(lastError: .timeout).
            switch error {
            case .timeout:
                break // direct timeout
            case .retryExhausted(let last):
                if case .timeout = last {
                    break // timeout wrapped by retry exhaustion
                } else {
                    Issue.record("Expected .timeout as lastError in retryExhausted, got \(last)")
                }
            default:
                Issue.record("Expected .timeout or .retryExhausted(.timeout), got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
