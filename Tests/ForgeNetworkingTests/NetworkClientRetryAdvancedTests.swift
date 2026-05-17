import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

// MARK: - Private endpoint stubs

private struct GetRetry: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/retry" }
    var method: HTTPMethod { .get }
}

private struct PostRetry: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/retry-post" }
    var method: HTTPMethod { .post }
}

// MARK: - Suite

@Suite("NetworkClient retry advanced", .serialized)
struct NetworkClientRetryAdvancedTests {

    // MARK: - Test A: Configured backoff actually delays between attempts

    @Test("Fixed backoff of 0.2s produces measurable delay between attempts")
    func backoffActuallyDelays() async throws {
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
        config.retryPolicy = RetryPolicy(maxAttempts: 2, backoff: .fixed(0.2))

        let client = NetworkClient(configuration: config)
        let start = Date()
        _ = try await client.send(GetRetry())
        let elapsed = Date().timeIntervalSince(start)

        // Should have waited at least ~0.18s (generous lower bound for scheduling jitter)
        #expect(elapsed >= 0.18, "Expected delay >= 0.18s due to .fixed(0.2) backoff, got \(elapsed)s")
    }

    // MARK: - Test B: Retry-After HTTP-date form is honored

    @Test("Retry-After HTTP-date header is honored and overrides long backoff")
    func retryAfterHTTPDateHonored() async throws {
        // HTTP-date has second-granularity, so use a future date well beyond 1 second
        // to survive the truncation to whole seconds and test scheduling overhead.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        // 2s in the future; second-truncation means actual delay will be 1-2s
        let retryAfterDate = Date().addingTimeInterval(2.0)
        let retryAfterValue = formatter.string(from: retryAfterDate)

        let count = LockedState(0)
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            let n = count.withLock { $0 += 1; return $0 }
            if n == 1 {
                return (HTTPURLResponse(
                    url: request.url!,
                    statusCode: 503,
                    httpVersion: nil,
                    headerFields: ["Retry-After": retryAfterValue]
                )!, Data())
            }
            let data = try JSONEncoder().encode(TestPayloadDTO(id: 1, name: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        // Long backoff (60s) ensures any actual delay comes from Retry-After, not the backoff
        config.retryPolicy = RetryPolicy(maxAttempts: 2, backoff: .fixed(60), honorsRetryAfter: true)

        let client = NetworkClient(configuration: config)
        let start = Date()
        _ = try await client.send(GetRetry())
        let elapsed = Date().timeIntervalSince(start)

        // Retry-After is 2s in the future (second-truncated). Expect at least 0.5s delay.
        // Upper bound is generous (5s) to absorb scheduling jitter.
        #expect(elapsed >= 0.5, "Expected delay >= 0.5s from Retry-After, got \(elapsed)s")
        #expect(elapsed < 5.0, "Expected delay < 5s, got \(elapsed)s")
    }

    // MARK: - Test C: Custom shouldRetry closure overrides method check

    @Test("Custom shouldRetry closure overrides default method check for POST")
    func customShouldRetryOverridesMethodCheck() async throws {
        let requestCount = LockedState(0)
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration { request in
            let n = requestCount.withLock { $0 += 1; return $0 }
            if n < 2 {
                // 422 is a client error — normally not retried, and POST is not in retryableMethods
                return (HTTPURLResponse(url: request.url!, statusCode: 422, httpVersion: nil, headerFields: nil)!, Data())
            }
            let data = try JSONEncoder().encode(TestPayloadDTO(id: 1, name: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        // Custom closure that always retries regardless of method or status
        config.retryPolicy = RetryPolicy(
            maxAttempts: 2,
            backoff: .fixed(0.001),
            shouldRetry: { _, _ in true }
        )

        let client = NetworkClient(configuration: config)
        let result = try await client.send(PostRetry())

        #expect(result.name == "ok")
        #expect(requestCount.withLock { $0 } == 2, "Expected exactly 2 requests (1 retry), got \(requestCount.withLock { $0 })")
    }
}
