import Foundation

public actor NetworkClient: NetworkClientProtocol {
    public let configuration: NetworkConfiguration
    private let session: URLSession
    private let interceptors: InterceptorChain
    private let gate: HostConcurrencyGate
    private let authEventsContinuation: AsyncStream<AuthEvent>.Continuation
    public nonisolated let authEvents: AsyncStream<AuthEvent>

    public init(configuration: NetworkConfiguration) {
        self.configuration = configuration
        self.session = URLSession(configuration: configuration.sessionConfiguration)
        self.interceptors = InterceptorChain(
            request: configuration.requestInterceptors,
            response: configuration.responseInterceptors
        )
        self.gate = HostConcurrencyGate(limit: configuration.maxConcurrentRequestsPerHost)
        var continuation: AsyncStream<AuthEvent>.Continuation!
        self.authEvents = AsyncStream { continuation = $0 }
        self.authEventsContinuation = continuation
    }

    public func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response {
        let policy = endpoint.retryPolicy ?? configuration.retryPolicy
        var attempt = 0
        var lastError: NetworkError?

        while attempt < policy.maxAttempts {
            attempt += 1
            do {
                return try await sendOnce(endpoint, allowRefresh: true)
            } catch let error as NetworkError {
                lastError = error
                // Check if this error type is retryable at all (ignoring attempt count).
                let isRetryable = policy.shouldRetry(error: error, method: endpoint.method, attempt: 0)
                guard isRetryable else {
                    throw error
                }
                // If we have more attempts remaining, sleep then retry.
                if attempt < policy.maxAttempts {
                    let delay = RetryExecutor.delay(for: error, attempt: attempt, policy: policy)
                    if delay > 0 {
                        try await Task.sleep(for: .seconds(delay))
                    }
                }
                // Otherwise fall through to retryExhausted below.
            }
        }
        throw NetworkError.retryExhausted(lastError: lastError ?? .unacceptableStatus(
            HTTPResponse(statusCode: 0, headers: [:], body: Data(),
                         request: URLRequest(url: configuration.baseURL))
        ))
    }

    private func sendOnce<E: Endpoint>(_ endpoint: E, allowRefresh: Bool) async throws -> E.Response {
        var built = try RequestBuilder.build(
            endpoint: endpoint,
            baseURL: configuration.baseURL,
            defaultHeaders: configuration.defaultHeaders,
            encoder: configuration.encoder
        )
        built.request.timeoutInterval = endpoint.timeout ?? configuration.timeout

        let activeAuth = self.activeAuthProvider(for: endpoint)
        if let auth = activeAuth {
            try await auth.apply(to: &built.request, endpoint: endpoint)
        }

        try await interceptors.applyRequest(&built.request, endpoint: endpoint)

        let host = built.request.url?.host ?? ""
        await gate.acquire(host: host)
        defer { Task { await gate.release(host: host) } }

        let (data, urlResponse) = try await performData(built)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw NetworkError.unacceptableStatus(
                HTTPResponse(statusCode: 0, headers: [:], body: data, request: built.request)
            )
        }

        var response = HTTPResponse(
            statusCode: http.statusCode,
            headers: Self.headers(from: http),
            body: data,
            request: built.request
        )
        try await interceptors.applyResponse(&response, endpoint: endpoint)

        // Refresh-once on 401
        if response.statusCode == 401, allowRefresh, let auth = activeAuth {
            let recovery = try await auth.handle(unauthorized: response)
            switch recovery {
            case .retry:
                authEventsContinuation.yield(.refreshed)
                return try await sendOnce(endpoint, allowRefresh: false)
            case .fail:
                authEventsContinuation.yield(.signedOut)
                throw NetworkError.unauthorized
            }
        }

        guard (200...299).contains(response.statusCode) else {
            throw NetworkError.from(response: response)
        }

        if E.Response.self == Empty.self {
            return Empty() as! E.Response
        }
        do {
            return try configuration.decoder.decode(E.Response.self, from: data)
        } catch {
            throw NetworkError.decoding(error, response)
        }
    }

    private func activeAuthProvider(for endpoint: any Endpoint) -> (any AuthProvider)? {
        switch endpoint.authentication {
        case .none: return nil
        case .override(let provider): return provider
        case .inherit: return configuration.authProvider
        }
    }

    public func sendWithProgress<E: ProgressReportingEndpoint>(
        _ endpoint: E
    ) async throws -> (E.Response, AsyncStream<TransferProgress>) {
        var built = try RequestBuilder.build(
            endpoint: endpoint,
            baseURL: configuration.baseURL,
            defaultHeaders: configuration.defaultHeaders,
            encoder: configuration.encoder
        )
        built.request.timeoutInterval = endpoint.timeout ?? configuration.timeout

        if let auth = activeAuthProvider(for: endpoint) {
            try await auth.apply(to: &built.request, endpoint: endpoint)
        }
        try await interceptors.applyRequest(&built.request, endpoint: endpoint)

        var continuation: AsyncStream<TransferProgress>.Continuation!
        let stream = AsyncStream<TransferProgress> { continuation = $0 }
        let delegate = ProgressDelegate(continuation: continuation)

        let host = built.request.url?.host ?? ""
        await gate.acquire(host: host)
        defer { Task { await gate.release(host: host) } }

        let (data, urlResponse): (Data, URLResponse)
        do {
            if let fileURL = built.bodyFileURL {
                (data, urlResponse) = try await session.upload(for: built.request, fromFile: fileURL, delegate: delegate)
            } else {
                (data, urlResponse) = try await session.data(for: built.request, delegate: delegate)
            }
        } catch let urlError as URLError {
            continuation.finish()
            switch urlError.code {
            case .timedOut: throw NetworkError.timeout
            case .cancelled: throw NetworkError.cancelled
            default: throw NetworkError.transport(urlError)
            }
        }

        continuation.finish()

        guard let http = urlResponse as? HTTPURLResponse else {
            throw NetworkError.unacceptableStatus(
                HTTPResponse(statusCode: 0, headers: [:], body: data, request: built.request)
            )
        }
        var response = HTTPResponse(
            statusCode: http.statusCode,
            headers: Self.headers(from: http),
            body: data,
            request: built.request
        )
        try await interceptors.applyResponse(&response, endpoint: endpoint)
        guard (200...299).contains(response.statusCode) else {
            throw NetworkError.from(response: response)
        }
        if E.Response.self == Empty.self { return (Empty() as! E.Response, stream) }
        do {
            let decoded = try configuration.decoder.decode(E.Response.self, from: data)
            return (decoded, stream)
        } catch {
            throw NetworkError.decoding(error, response)
        }
    }

    // MARK: - Internal

    private func performData(_ built: BuiltRequest) async throws -> (Data, URLResponse) {
        do {
            if let fileURL = built.bodyFileURL {
                return try await session.upload(for: built.request, fromFile: fileURL)
            }
            return try await session.data(for: built.request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut: throw NetworkError.timeout
            case .cancelled: throw NetworkError.cancelled
            default: throw NetworkError.transport(urlError)
            }
        }
    }

    nonisolated static func headers(from response: HTTPURLResponse) -> [String: String] {
        var dict: [String: String] = [:]
        for (k, v) in response.allHeaderFields {
            if let key = k as? String, let value = v as? String { dict[key] = value }
        }
        return dict
    }
}
