import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

// MARK: - Shared endpoints

private struct GetScenario: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/scenario" }
    var method: HTTPMethod { .get }
}

private struct GetNoContent: Endpoint {
    typealias Body = Empty
    typealias Response = Empty
    var path: String { "/empty" }
    var method: HTTPMethod { .get }
}

private struct ThrowingRequestInterceptor: RequestInterceptor {
    func intercept(_ request: inout URLRequest, endpoint: any Endpoint) async throws {
        struct Boom: Error {}
        throw Boom()
    }
}

private struct ProgressScenarioEndpoint: ProgressReportingEndpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/upload-scenario" }
    var method: HTTPMethod { .post }
    var body: RequestBody<Empty> {
        var mp = MultipartBody(boundary: "scenario-boundary")
        mp.append(data: Data("payload".utf8), name: "file", filename: "f.txt", contentType: "text/plain")
        return .multipart(mp)
    }
}

// MARK: - Suite

@Suite("NetworkClient scenario coverage", .serialized)
struct NetworkClientScenariosTests {

    // MARK: 1 — 204 No Content with Empty response

    @Test("204 No Content returns Empty without a decode error")
    func noContentReturnsEmpty() async throws {
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.retryPolicy = RetryPolicy(maxAttempts: 1)

        let client = NetworkClient(configuration: config)
        let result = try await client.send(GetNoContent())
        #expect(result == Empty())
    }

    // MARK: 2 — 401 without auth provider → .unauthorized

    @Test("401 without auth provider throws .unauthorized via status mapping")
    func unauthorizedWithoutProvider() async {
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.authProvider = nil
        config.retryPolicy = RetryPolicy(maxAttempts: 1)

        let client = NetworkClient(configuration: config)
        do {
            _ = try await client.send(GetScenario())
            Issue.record("Expected throw")
        } catch NetworkError.unauthorized {
            // expected
        } catch {
            Issue.record("Expected .unauthorized, got \(error)")
        }
    }

    // MARK: 3 — 401 → refresh → second 401 → throws (no infinite loop)

    @Test("401 always returned: refresh then second 401 terminates")
    func doubleUnauthorizedTerminates() async throws {
        let requestCount = LockedState(0)
        MockURLProtocol.handler = { request in
            requestCount.withLock { $0 += 1 }
            return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "old", refreshToken: "r"))
        let coord = RefreshCoordinator { _ in TokenPair(accessToken: "new", refreshToken: "r2") }
        let provider = BearerAuthProvider(store: store, coordinator: coord)

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.authProvider = provider
        config.retryPolicy = RetryPolicy(maxAttempts: 1)

        let client = NetworkClient(configuration: config)
        await #expect(throws: NetworkError.self) {
            _ = try await client.send(GetScenario())
        }
        // first request + one retry after refresh = exactly 2 requests
        #expect(requestCount.withLock { $0 } == 2)
    }

    // MARK: 4 — Request interceptor throws → .interceptorFailed

    @Test("Request interceptor throwing surfaces .interceptorFailed")
    func requestInterceptorThrows() async {
        MockURLProtocol.handler = { _ in
            // Should never be reached
            (HTTPURLResponse(url: URL(string: "https://x.test/scenario")!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.requestInterceptors = [ThrowingRequestInterceptor()]
        config.retryPolicy = RetryPolicy(maxAttempts: 1)

        let client = NetworkClient(configuration: config)
        do {
            _ = try await client.send(GetScenario())
            Issue.record("Expected throw")
        } catch let NetworkError.interceptorFailed(underlying) {
            _ = underlying // confirms wrapped correctly
        } catch {
            Issue.record("Expected .interceptorFailed, got \(error)")
        }
    }

    // MARK: 5 — sendWithProgress applies auth header

    @Test("sendWithProgress applies BearerAuth header and succeeds")
    func sendWithProgressAppliesAuth() async throws {
        let seenAuth = LockedState<String?>(nil)
        MockURLProtocol.handler = { request in
            seenAuth.withLock { $0 = request.value(forHTTPHeaderField: "Authorization") }
            let dto = TestPayloadDTO(id: 99, name: "uploaded")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "abc", refreshToken: "r"))
        let coord = RefreshCoordinator { _ in TokenPair(accessToken: "new", refreshToken: "r2") }
        let provider = BearerAuthProvider(store: store, coordinator: coord)

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.authProvider = provider

        let client = NetworkClient(configuration: config)
        let (response, stream) = try await client.sendWithProgress(ProgressScenarioEndpoint())
        // drain stream
        for await _ in stream {}
        #expect(response.id == 99)
        #expect(seenAuth.withLock { $0 } == "Bearer abc")
    }

    // MARK: 6 — 5xx empty body → .serverError with nil payload
    // Note: With maxAttempts: 1, the retry loop exhausts after one attempt and wraps
    // the underlying error in .retryExhausted. We unwrap it to verify the inner
    // .serverError has a nil payload.

    @Test("503 with empty body: inner .serverError has nil payload")
    func serverErrorEmptyBodyNilPayload() async {
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
        }
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.retryPolicy = RetryPolicy(maxAttempts: 1)

        let client = NetworkClient(configuration: config)
        do {
            _ = try await client.send(GetScenario())
            Issue.record("Expected throw")
        } catch let NetworkError.serverError(response, payload) {
            #expect(response.statusCode == 503)
            #expect(payload == nil)
        } catch let NetworkError.retryExhausted(lastError) {
            // Unwrap the retryExhausted wrapper to inspect the actual error
            if case .serverError(let response, let payload) = lastError {
                #expect(response.statusCode == 503)
                #expect(payload == nil)
            } else {
                Issue.record("Expected inner .serverError, got \(lastError)")
            }
        } catch {
            Issue.record("Expected .serverError or .retryExhausted wrapping it, got \(error)")
        }
    }
}
