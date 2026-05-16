import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

/// Captures URLSessionDelegate callbacks so the test can assert on them.
private final class CapturingDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    let didCollectMetrics = LockedState(0)
    let didReceiveChallenge = LockedState(0)

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        didCollectMetrics.withLock { $0 += 1 }
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        didReceiveChallenge.withLock { $0 += 1 }
        completionHandler(.performDefaultHandling, nil)
    }
}

private struct GetItem: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/items/1" }
    var method: HTTPMethod { .get }
}

@Suite("URLSessionDelegate hook", .serialized)
struct SessionDelegateHookTests {
    @Test("Custom session delegate receives didFinishCollecting metrics")
    func receivesMetrics() async throws {
        let delegate = CapturingDelegate()
        MockURLProtocol.handler = { request in
            let dto = TestPayloadDTO(id: 1, name: "ok")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.sessionDelegate = delegate

        let client = NetworkClient(configuration: config)
        _ = try await client.send(GetItem())

        // Metrics arrive asynchronously — give it a moment.
        try? await Task.sleep(for: .milliseconds(100))
        #expect(delegate.didCollectMetrics.withLock { $0 } >= 1)
    }

    @Test("Without a custom delegate, baseline send still works")
    func noDelegateBaseline() async throws {
        MockURLProtocol.handler = { request in
            let dto = TestPayloadDTO(id: 1, name: "ok")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        // sessionDelegate not set — defaults to nil

        let client = NetworkClient(configuration: config)
        let result = try await client.send(GetItem())
        #expect(result.name == "ok")
    }
}
