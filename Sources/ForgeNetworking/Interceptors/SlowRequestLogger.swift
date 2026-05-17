import Foundation
import ForgeCore

/// Interceptor pair that logs requests exceeding a configurable duration threshold.
/// Useful for diagnosing slow endpoints in production.
///
/// ```swift
/// let slowLogger = SlowRequestLogger(threshold: 1.0, logger: OSLogNetworkLogger())
/// config.requestInterceptors = [slowLogger]
/// config.responseInterceptors = [slowLogger]
/// ```
public final class SlowRequestLogger: RequestInterceptor, ResponseInterceptor, @unchecked Sendable {

    public let threshold: TimeInterval
    public let logger: any NetworkLogger

    private let starts = LockedState<[String: Date]>([:])
    private static let trackingHeader = "X-ForgeNet-SlowLog-Id"

    public init(threshold: TimeInterval, logger: any NetworkLogger) {
        self.threshold = threshold
        self.logger = logger
    }

    public func intercept(_ request: inout URLRequest, endpoint: any Endpoint) async throws {
        let id = UUID().uuidString
        request.setValue(id, forHTTPHeaderField: Self.trackingHeader)
        starts.withLock { $0[id] = Date() }
    }

    public func intercept(_ response: inout HTTPResponse, for endpoint: any Endpoint) async throws {
        let id = response.request.value(forHTTPHeaderField: Self.trackingHeader)
        guard let id, let start = starts.withLock({ $0.removeValue(forKey: id) }) else { return }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed >= threshold {
            let method = response.request.httpMethod ?? "?"
            let url = response.request.url?.absoluteString ?? "?"
            let ms = Int(elapsed * 1000)
            logger.log("[slow] \(method) \(url) took \(ms)ms (threshold \(Int(threshold * 1000))ms, status \(response.statusCode))")
        }
    }
}
