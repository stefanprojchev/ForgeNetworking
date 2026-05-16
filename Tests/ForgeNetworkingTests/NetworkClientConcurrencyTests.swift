import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

private struct ConcItem: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/items/1" }
    var method: HTTPMethod { .get }
}

@Suite("NetworkClient concurrency", .serialized)
struct NetworkClientConcurrencyTests {

    // MARK: - Test A: Concurrent 401s trigger exactly one refresh

    @Test("Concurrent 401s trigger exactly one refresh and all retry with the new token")
    func concurrentRefreshDeduplication() async throws {
        let refreshCount = LockedState(0)
        let capturedHeaders = LockedState<[String]>([])

        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "old", refreshToken: "r"))
        let coord = RefreshCoordinator { _ in
            refreshCount.withLock { $0 += 1 }
            // Simulate refresh latency so concurrent requests collide on the in-flight task
            try await Task.sleep(for: .milliseconds(50))
            return TokenPair(accessToken: "new", refreshToken: "r2")
        }
        let provider = BearerAuthProvider(store: store, coordinator: coord)

        MockURLProtocol.handler = { request in
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
            capturedHeaders.withLock { $0.append(auth) }
            if auth == "Bearer old" {
                return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
            }
            let data = try JSONEncoder().encode(TestPayloadDTO(id: 1, name: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.authProvider = provider
        config.retryPolicy = RetryPolicy(maxAttempts: 1)

        let client = NetworkClient(configuration: config)

        // Fire 5 concurrent requests
        async let r1 = client.send(ConcItem())
        async let r2 = client.send(ConcItem())
        async let r3 = client.send(ConcItem())
        async let r4 = client.send(ConcItem())
        async let r5 = client.send(ConcItem())

        let results = try await [r1, r2, r3, r4, r5]

        // All 5 should return the DTO
        #expect(results.count == 5)
        for result in results {
            #expect(result.name == "ok")
        }

        // Exactly one refresh should have been triggered
        let observed = refreshCount.withLock { $0 }
        #expect(observed == 1)

        // Headers: at least one "Bearer old" (the initial attempts) and at least one "Bearer new" (retries)
        let headers = capturedHeaders.withLock { $0 }
        #expect(headers.filter { $0 == "Bearer old" }.count >= 1)
        #expect(headers.filter { $0 == "Bearer new" }.count >= 1)
    }

    // MARK: - Test B: authEvents emits .refreshed on successful refresh

    @Test("authEvents emits .refreshed on successful refresh retry")
    func authEventsRefreshed() async throws {
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "old", refreshToken: "r"))
        let coord = RefreshCoordinator { _ in TokenPair(accessToken: "new", refreshToken: "r2") }
        let provider = BearerAuthProvider(store: store, coordinator: coord)

        MockURLProtocol.handler = { request in
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if auth == "Bearer old" {
                return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
            }
            let data = try JSONEncoder().encode(TestPayloadDTO(id: 1, name: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.authProvider = provider
        config.retryPolicy = RetryPolicy(maxAttempts: 1)

        let client = NetworkClient(configuration: config)

        // Subscribe BEFORE sending
        let stream = await client.authEvents
        let collector = Task<AuthEvent?, Never> {
            for await event in stream { return event }
            return nil
        }

        _ = try await client.send(ConcItem())
        collector.cancel()

        let event = await collector.value
        if let event {
            if case .refreshed = event {
                // pass
            } else {
                Issue.record("Expected .refreshed event, got \(event)")
            }
        } else {
            Issue.record("Expected an auth event but got nil")
        }
    }

    // MARK: - Test C: Task cancellation surfaces NetworkError.cancelled

    @Test("Task.cancel() during send surfaces NetworkError.cancelled or transport cancelled")
    func cancellationSurfacesError() async throws {
        MockURLProtocol.handler = { request in
            // Delay long enough for the task to be cancelled before response
            Thread.sleep(forTimeInterval: 1.0)
            let data = try JSONEncoder().encode(TestPayloadDTO(id: 1, name: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.retryPolicy = RetryPolicy(maxAttempts: 1)

        let client = NetworkClient(configuration: config)

        let task = Task<TestPayloadDTO, Error> {
            try await client.send(ConcItem())
        }

        // Give the task a moment to start, then cancel
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation error but got success")
        } catch let error as NetworkError {
            switch error {
            case .cancelled:
                break // expected
            case .transport(let urlError) where urlError.code == .cancelled:
                break // also acceptable
            default:
                Issue.record("Expected .cancelled or transport(URLError.cancelled), got \(error)")
            }
        } catch {
            // CancellationError from Task.sleep is also acceptable
            // (when the task is cancelled before the request even starts)
        }
    }
}
