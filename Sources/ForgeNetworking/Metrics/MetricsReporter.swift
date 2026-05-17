import Foundation

/// A captured measurement for one logical `send(_:)` call (including all retries).
public struct RequestMetric: Sendable {
    /// The Swift type name of the endpoint (`String(describing: E.self)`).
    public let endpointTypeName: String
    /// The HTTP method of the endpoint.
    public let method: HTTPMethod
    /// The path of the endpoint.
    public let path: String
    /// Total wall-clock duration of the `send(_:)` call, including all retry waits.
    public let duration: TimeInterval
    /// Number of network attempts made (1 means first try succeeded or failed without retry).
    public let attempts: Int
    /// HTTP status code of the final response. `nil` if the request never reached the server.
    public let statusCode: Int?
    /// Request body size in bytes (best-effort; 0 for bodyless requests).
    public let bytesOut: Int
    /// Response body size in bytes (0 on error paths where no response body was received).
    public let bytesIn: Int
    /// `nil` on success; the terminal `NetworkError` on failure.
    public let error: NetworkError?

    public init(
        endpointTypeName: String,
        method: HTTPMethod,
        path: String,
        duration: TimeInterval,
        attempts: Int,
        statusCode: Int?,
        bytesOut: Int,
        bytesIn: Int,
        error: NetworkError?
    ) {
        self.endpointTypeName = endpointTypeName
        self.method = method
        self.path = path
        self.duration = duration
        self.attempts = attempts
        self.statusCode = statusCode
        self.bytesOut = bytesOut
        self.bytesIn = bytesIn
        self.error = error
    }

    /// `true` if the request completed without error.
    public var isSuccess: Bool { error == nil }
}

/// Receives one `RequestMetric` per `send(_:)` call. Implementers typically forward to a
/// metrics backend (CloudWatch, Datadog, Firebase Performance, custom analytics).
///
/// The reporter is called asynchronously after the response returns (or the final error is
/// determined). It never blocks the caller.
public protocol MetricsReporter: Sendable {
    func record(_ metric: RequestMetric) async
}
