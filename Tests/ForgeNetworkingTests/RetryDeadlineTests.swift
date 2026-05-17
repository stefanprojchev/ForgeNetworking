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

@Suite("RetryPolicy deadline")
struct RetryDeadlineTests {
    @Test("Default deadline is nil (no time limit)")
    func defaultDeadlineIsNil() {
        let p = RetryPolicy.default
        #expect(p.deadline == nil)
    }

    @Test("Deadline stops retry loop before exceeding total elapsed time")
    func stopsAtDeadline() async throws {
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            (HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
        }
        // Long backoff (1s each), short deadline (0.5s) → at most 1 attempt before deadline kicks in
        config.retryPolicy = RetryPolicy(
            maxAttempts: 5,
            backoff: .fixed(1.0),
            deadline: 0.5
        )
        let client = NetworkClient(configuration: config)

        let start = Date()
        do {
            _ = try await client.send(GetItem())
            Issue.record("expected throw")
        } catch let NetworkError.retryExhausted(last) {
            if case .serverError = last {} else { Issue.record("expected serverError inner") }
        } catch {
            Issue.record("unexpected error \(error)")
        }
        let elapsed = Date().timeIntervalSince(start)
        // Should fail FAST (well under 2s) because deadline 0.5s prevents the second backoff
        #expect(elapsed < 2.0, "elapsed was \(elapsed)s — deadline should have prevented further retries")
    }

    @Test("No deadline allows full retry cycle (current behavior)")
    func noDeadlineAllowsFullRetries() async throws {
        let count = LockedState(0)
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            count.withLock { $0 += 1 }
            return (HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
        }
        config.retryPolicy = RetryPolicy(maxAttempts: 3, backoff: .fixed(0.01))
        let client = NetworkClient(configuration: config)
        do {
            _ = try await client.send(GetItem())
            Issue.record("expected throw")
        } catch {
            // expected
        }
        #expect(count.withLock { $0 } == 3)
    }

    @Test("Deadline larger than total backoff allows all retries")
    func generousDeadlineAllowsRetries() async throws {
        let count = LockedState(0)
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            count.withLock { $0 += 1 }
            return (HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
        }
        config.retryPolicy = RetryPolicy(
            maxAttempts: 3,
            backoff: .fixed(0.05),
            deadline: 10.0    // 10s is way more than 3 attempts * 0.05s
        )
        let client = NetworkClient(configuration: config)
        do {
            _ = try await client.send(GetItem())
            Issue.record("expected throw")
        } catch {
            // expected
        }
        #expect(count.withLock { $0 } == 3)
    }
}
