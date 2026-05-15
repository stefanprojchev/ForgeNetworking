import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

private struct ProtectedItem: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/items/1" }
    var method: HTTPMethod { .get }
}

@Suite("NetworkClient auth + refresh", .serialized)
struct NetworkClientAuthTests {
    @Test("Bearer token is added by configured AuthProvider")
    func appliesBearer() async throws {
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "abc", refreshToken: "r"))
        let coord = RefreshCoordinator { _ in TokenPair(accessToken: "n", refreshToken: "n") }
        let provider = BearerAuthProvider(store: store, coordinator: coord)

        MockURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
            let data = try JSONEncoder().encode(TestPayloadDTO(id: 1, name: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.authProvider = provider

        let client = NetworkClient(configuration: config)
        _ = try await client.send(ProtectedItem())
    }

    @Test("On 401 the client refreshes once and retries with the new token")
    func refreshesOnceAndRetries() async throws {
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "old", refreshToken: "r"))
        let coord = RefreshCoordinator { _ in TokenPair(accessToken: "new", refreshToken: "r2") }
        let provider = BearerAuthProvider(store: store, coordinator: coord)
        let calls = LockedState<[String]>([])

        MockURLProtocol.handler = { request in
            let token = request.value(forHTTPHeaderField: "Authorization") ?? ""
            calls.withLock { $0.append(token) }
            if token == "Bearer old" {
                return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
            }
            let data = try JSONEncoder().encode(TestPayloadDTO(id: 1, name: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.authProvider = provider
        config.retryPolicy = RetryPolicy(maxAttempts: 1) // disable transport retries for clarity

        let client = NetworkClient(configuration: config)
        let result = try await client.send(ProtectedItem())
        #expect(result.name == "ok")
        let observed = calls.withLock { $0 }
        #expect(observed.count == 2)
        #expect(observed[0] == "Bearer old")
        #expect(observed[1] == "Bearer new")
    }

    @Test("Refresh failure surfaces .unauthorized and emits signedOut event")
    func refreshFailureSignsOut() async throws {
        struct Boom: Error {}
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "old", refreshToken: "r"))
        let coord = RefreshCoordinator { _ -> TokenPair in throw Boom() }
        let provider = BearerAuthProvider(store: store, coordinator: coord)

        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.authProvider = provider
        config.retryPolicy = RetryPolicy(maxAttempts: 1)

        let client = NetworkClient(configuration: config)

        // Subscribe before sending so events aren't dropped.
        let stream = await client.authEvents
        let collector = Task<AuthEvent?, Never> {
            for await event in stream { return event }
            return nil
        }

        await #expect(throws: NetworkError.self) {
            _ = try await client.send(ProtectedItem())
        }

        let event = await collector.value
        if case .signedOut = event {} else { Issue.record("expected signedOut event") }
    }
}
