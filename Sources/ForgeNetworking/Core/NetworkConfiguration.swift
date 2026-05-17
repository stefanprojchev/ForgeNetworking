import Foundation

public struct NetworkConfiguration: Sendable {
    public var baseURL: URL
    public var defaultHeaders: [String: String]
    public var encoder: JSONEncoder
    public var decoder: JSONDecoder
    public var sessionConfiguration: URLSessionConfiguration
    public var sessionDelegate: (any URLSessionDelegate & Sendable)?
    public var requestInterceptors: [any RequestInterceptor]
    public var responseInterceptors: [any ResponseInterceptor]
    public var authProvider: (any AuthProvider)?
    public var retryPolicy: RetryPolicy
    public var maxConcurrentRequestsPerHost: Int?
    public var timeout: TimeInterval
    public var logger: (any NetworkLogger)?
    public var urlCache: URLCache?
    /// Optional metrics reporter. When set, one `RequestMetric` is emitted per `send(_:)` call
    /// (after all retries). The reporter is called asynchronously and never blocks the response.
    public var metricsReporter: (any MetricsReporter)?

    public init(
        baseURL: URL,
        defaultHeaders: [String: String] = [:],
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        sessionConfiguration: URLSessionConfiguration = .default,
        sessionDelegate: (any URLSessionDelegate & Sendable)? = nil,
        requestInterceptors: [any RequestInterceptor] = [],
        responseInterceptors: [any ResponseInterceptor] = [],
        authProvider: (any AuthProvider)? = nil,
        retryPolicy: RetryPolicy = .default,
        maxConcurrentRequestsPerHost: Int? = nil,
        timeout: TimeInterval = 60,
        logger: (any NetworkLogger)? = nil,
        urlCache: URLCache? = nil,
        metricsReporter: (any MetricsReporter)? = nil
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.encoder = encoder
        self.decoder = decoder
        self.sessionConfiguration = sessionConfiguration
        self.sessionDelegate = sessionDelegate
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
        self.authProvider = authProvider
        self.retryPolicy = retryPolicy
        self.maxConcurrentRequestsPerHost = maxConcurrentRequestsPerHost
        self.timeout = timeout
        self.logger = logger
        self.urlCache = urlCache
        self.metricsReporter = metricsReporter
    }
}
