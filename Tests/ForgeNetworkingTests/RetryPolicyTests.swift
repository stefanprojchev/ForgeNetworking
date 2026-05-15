import Testing
import Foundation
@testable import ForgeNetworking

@Suite("RetryPolicy")
struct RetryPolicyTests {
    @Test("Default policy retries idempotent methods on retryable statuses")
    func defaultRetries() {
        let p = RetryPolicy.default
        let req = URLRequest(url: URL(string: "https://x.test")!)
        let response = HTTPResponse(statusCode: 503, headers: [:], body: Data(), request: req)
        #expect(p.shouldRetry(error: NetworkError.serverError(response, nil), method: .get, attempt: 1))
    }

    @Test("Default policy does not retry POST")
    func noPostRetry() {
        let p = RetryPolicy.default
        let req = URLRequest(url: URL(string: "https://x.test")!)
        let response = HTTPResponse(statusCode: 503, headers: [:], body: Data(), request: req)
        #expect(!p.shouldRetry(error: NetworkError.serverError(response, nil), method: .post, attempt: 1))
    }

    @Test("Stops after maxAttempts")
    func stopsAtMax() {
        let p = RetryPolicy.default
        let req = URLRequest(url: URL(string: "https://x.test")!)
        let response = HTTPResponse(statusCode: 503, headers: [:], body: Data(), request: req)
        #expect(!p.shouldRetry(error: NetworkError.serverError(response, nil), method: .get, attempt: p.maxAttempts))
    }

    @Test("Retries transport URL errors on idempotent methods")
    func retriesTransport() {
        let p = RetryPolicy.default
        let err = NetworkError.transport(URLError(.networkConnectionLost))
        #expect(p.shouldRetry(error: err, method: .get, attempt: 1))
    }

    @Test("Custom shouldRetry override is honored")
    func customOverride() {
        var p = RetryPolicy.default
        p.shouldRetry = { _, _ in true }
        let err = NetworkError.encoding(URLError(.cannotParseResponse))
        #expect(p.shouldRetry(error: err, method: .post, attempt: 1))
    }
}
