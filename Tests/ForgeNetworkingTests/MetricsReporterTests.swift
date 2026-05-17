import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

private final class CapturingReporter: MetricsReporter {
    let metrics = LockedState<[RequestMetric]>([])
    func record(_ metric: RequestMetric) async {
        metrics.withLock { $0.append(metric) }
    }
}

private struct GetItem: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/items/42" }
    var method: HTTPMethod { .get }
}

private struct PostItem: Endpoint {
    typealias Body = TestPayloadDTO
    typealias Response = TestPayloadDTO
    let payload: TestPayloadDTO
    var path: String { "/items" }
    var method: HTTPMethod { .post }
    var body: RequestBody<TestPayloadDTO> { .json(payload) }
}

@Suite("MetricsReporter")
struct MetricsReporterTests {
    @Test("Successful send emits a single metric with attempts=1")
    func successEmitsMetric() async throws {
        let reporter = CapturingReporter()
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            let dto = TestPayloadDTO(id: 42, name: "alice")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        config.metricsReporter = reporter
        let client = NetworkClient(configuration: config)
        _ = try await client.send(GetItem())

        let metrics = reporter.metrics.withLock { $0 }
        #expect(metrics.count == 1)
        let m = metrics[0]
        #expect(m.endpointTypeName.contains("GetItem"))
        #expect(m.method == .get)
        #expect(m.path == "/items/42")
        #expect(m.attempts == 1)
        #expect(m.statusCode == 200)
        #expect(m.bytesIn > 0)
        #expect(m.error == nil)
        #expect(m.isSuccess)
    }

    @Test("Failed send emits a metric with error set and isSuccess == false")
    func failureEmitsMetric() async {
        let reporter = CapturingReporter()
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }
        config.metricsReporter = reporter
        config.retryPolicy = RetryPolicy(maxAttempts: 1)
        let client = NetworkClient(configuration: config)
        do {
            _ = try await client.send(GetItem())
            Issue.record("expected throw")
        } catch { /* expected */ }

        let metrics = reporter.metrics.withLock { $0 }
        #expect(metrics.count == 1)
        let m = metrics[0]
        #expect(!m.isSuccess)
        #expect(m.statusCode == 404)
        if case .notFound = m.error {} else { Issue.record("expected notFound error") }
    }

    @Test("Retried request reports attempts > 1")
    func retriedReportsAttempts() async throws {
        let count = LockedState(0)
        let reporter = CapturingReporter()
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            let n = count.withLock { $0 += 1; return $0 }
            if n < 3 {
                return (HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
            }
            let dto = TestPayloadDTO(id: 1, name: "ok")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        config.metricsReporter = reporter
        config.retryPolicy = RetryPolicy(maxAttempts: 4, backoff: .fixed(0.001))
        let client = NetworkClient(configuration: config)
        _ = try await client.send(GetItem())

        let metrics = reporter.metrics.withLock { $0 }
        #expect(metrics.count == 1)
        #expect(metrics[0].attempts == 3)
        #expect(metrics[0].statusCode == 200)
    }

    @Test("bytesOut reflects request body size for POST")
    func bytesOutForPost() async throws {
        let reporter = CapturingReporter()
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            let dto = TestPayloadDTO(id: 1, name: "ok")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        config.metricsReporter = reporter
        let client = NetworkClient(configuration: config)
        let payload = TestPayloadDTO(id: 42, name: "alice")
        _ = try await client.send(PostItem(payload: payload))

        let metrics = reporter.metrics.withLock { $0 }
        #expect(metrics.count == 1)
        #expect(metrics[0].bytesOut > 0)
    }

    @Test("No reporter configured: no metrics, no crash, just works")
    func noReporterStillWorks() async throws {
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            let dto = TestPayloadDTO(id: 1, name: "ok")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        // metricsReporter NOT set
        let client = NetworkClient(configuration: config)
        let dto = try await client.send(GetItem())
        #expect(dto.name == "ok")
    }
}
