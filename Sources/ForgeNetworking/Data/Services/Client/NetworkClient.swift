import Foundation

public actor NetworkClient: NetworkClientProtocol {

    // MARK: - Dependencies

    public let configuration: NetworkConfiguration
    private let session: URLSession
    private let interceptors: InterceptorChain
    private let gate: HostConcurrencyGate
    private let authEventsContinuation: AsyncStream<AuthEvent>.Continuation
    public nonisolated let authEvents: AsyncStream<AuthEvent>

    // MARK: - Init

    public init(configuration: NetworkConfiguration) {
        self.configuration = configuration
        let sessionConfig = configuration.sessionConfiguration.copy() as! URLSessionConfiguration
        if let urlCache = configuration.urlCache {
            sessionConfig.urlCache = urlCache
        }
        if let delegate = configuration.sessionDelegate {
            self.session = URLSession(
                configuration: sessionConfig,
                delegate: delegate,
                delegateQueue: nil
            )
        } else {
            self.session = URLSession(configuration: sessionConfig)
        }
        self.interceptors = InterceptorChain(
            request: configuration.requestInterceptors,
            response: configuration.responseInterceptors
        )
        self.gate = HostConcurrencyGate(limit: configuration.maxConcurrentRequestsPerHost)
        var continuation: AsyncStream<AuthEvent>.Continuation!
        self.authEvents = AsyncStream { continuation = $0 }
        self.authEventsContinuation = continuation
    }

    // MARK: - Implementation

    public func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response {
        let policy = endpoint.retryPolicy ?? configuration.retryPolicy
        var attempt = 0
        var lastError: NetworkError?
        var lastStats = RequestStats()
        let startTime = Date()

        // Generate idempotency key once for the entire send (incl. retries + refresh-retry)
        let idempotencyKey: String? = endpoint.idempotencyKeyEnabled ? UUID().uuidString : nil

        while attempt < policy.maxAttempts {
            attempt += 1
            do {
                let (result, stats) = try await sendOnce(endpoint, allowRefresh: true, idempotencyKey: idempotencyKey)
                lastStats = stats
                await reportMetric(
                    endpoint: endpoint,
                    attempts: attempt,
                    duration: Date().timeIntervalSince(startTime),
                    stats: lastStats,
                    error: nil
                )
                return result
            } catch let error as NetworkError {
                lastError = error
                lastStats.statusCode = Self.extractStatus(from: error)
                // Check if this error type is retryable at all (ignoring attempt count).
                let isRetryable = policy.shouldRetry(error: error, method: endpoint.method, attempt: 0)
                guard isRetryable else {
                    await reportMetric(
                        endpoint: endpoint,
                        attempts: attempt,
                        duration: Date().timeIntervalSince(startTime),
                        stats: lastStats,
                        error: error
                    )
                    throw error
                }
                // If we have more attempts remaining, check deadline then sleep.
                if attempt < policy.maxAttempts {
                    let delay = RetryExecutor.delay(for: error, attempt: attempt, policy: policy)
                    // Deadline check: if the planned backoff would push past the deadline, stop now.
                    if let deadline = policy.deadline {
                        let elapsed = Date().timeIntervalSince(startTime)
                        if elapsed + delay > deadline {
                            let final = NetworkError.retryExhausted(lastError: error)
                            await reportMetric(
                                endpoint: endpoint,
                                attempts: attempt,
                                duration: Date().timeIntervalSince(startTime),
                                stats: lastStats,
                                error: final
                            )
                            throw final
                        }
                    }
                    if delay > 0 {
                        try await Task.sleep(for: .seconds(delay))
                    }
                }
                // Otherwise fall through to retryExhausted below.
            }
        }
        let exhausted = NetworkError.retryExhausted(lastError: lastError ?? .unacceptableStatus(
            HTTPResponse(statusCode: 0, headers: [:], body: Data(),
                         request: URLRequest(url: configuration.baseURL))
        ))
        await reportMetric(
            endpoint: endpoint,
            attempts: attempt,
            duration: Date().timeIntervalSince(startTime),
            stats: lastStats,
            error: exhausted
        )
        throw exhausted
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

        if endpoint.idempotencyKeyEnabled {
            built.request.setValue(UUID().uuidString, forHTTPHeaderField: endpoint.idempotencyKeyHeaderName)
        }

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
            } else if let bodyData = built.request.httpBody, !bodyData.isEmpty {
                // Use upload(for:from:) for explicit progress reporting on body uploads (raw, JSON, form).
                var requestNoBody = built.request
                requestNoBody.httpBody = nil
                (data, urlResponse) = try await session.upload(for: requestNoBody, from: bodyData, delegate: delegate)
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
        if let acceptable = endpoint.acceptableContentTypes,
           !Self.matchesContentType(response.value(forHeader: "Content-Type"), acceptable: acceptable) {
            throw NetworkError.unacceptableContentType(
                response,
                expected: acceptable,
                actual: response.value(forHeader: "Content-Type")
            )
        }
        if E.Response.self == Empty.self { return (Empty() as! E.Response, stream) }
        do {
            let decoded = try endpoint.decodeResponse(from: data, response: response, using: configuration.decoder)
            return (decoded, stream)
        } catch {
            throw NetworkError.decoding(error, response)
        }
    }

    public func stream<E: Endpoint>(
        _ endpoint: E
    ) async throws -> (HTTPResponse, AsyncThrowingStream<Data, any Error>) {
        var built = try RequestBuilder.build(
            endpoint: endpoint,
            baseURL: configuration.baseURL,
            defaultHeaders: configuration.defaultHeaders,
            encoder: configuration.encoder
        )
        built.request.timeoutInterval = endpoint.timeout ?? configuration.timeout

        if endpoint.idempotencyKeyEnabled {
            built.request.setValue(UUID().uuidString, forHTTPHeaderField: endpoint.idempotencyKeyHeaderName)
        }

        if let auth = activeAuthProvider(for: endpoint) {
            try await auth.apply(to: &built.request, endpoint: endpoint)
        }
        try await interceptors.applyRequest(&built.request, endpoint: endpoint)

        let host = built.request.url?.host ?? ""
        await gate.acquire(host: host)

        let (bytes, urlResponse): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, urlResponse) = try await session.bytes(for: built.request)
        } catch let urlError as URLError {
            await gate.release(host: host)
            switch urlError.code {
            case .timedOut: throw NetworkError.timeout
            case .cancelled: throw NetworkError.cancelled
            default: throw NetworkError.transport(urlError)
            }
        } catch {
            await gate.release(host: host)
            throw error
        }

        guard let http = urlResponse as? HTTPURLResponse else {
            await gate.release(host: host)
            throw NetworkError.unacceptableStatus(
                HTTPResponse(statusCode: 0, headers: [:], body: Data(), request: built.request)
            )
        }

        var response = HTTPResponse(
            statusCode: http.statusCode,
            headers: Self.headers(from: http),
            body: Data(),
            request: built.request
        )
        try await interceptors.applyResponse(&response, endpoint: endpoint)

        guard (200...299).contains(response.statusCode) else {
            await gate.release(host: host)
            throw NetworkError.from(response: response)
        }

        // Build a chunked stream that releases the concurrency gate when it ends.
        let chunkSize = 16 * 1024
        let gate = self.gate
        let dataStream = AsyncThrowingStream<Data, any Error> { continuation in
            let task = Task {
                do {
                    var buffer = Data()
                    buffer.reserveCapacity(chunkSize)
                    for try await byte in bytes {
                        buffer.append(byte)
                        if buffer.count >= chunkSize {
                            continuation.yield(buffer)
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !buffer.isEmpty {
                        continuation.yield(buffer)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                await gate.release(host: host)
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }

        return (response, dataStream)
    }

    nonisolated static func headers(from response: HTTPURLResponse) -> [String: String] {
        var dict: [String: String] = [:]
        for (k, v) in response.allHeaderFields {
            if let key = k as? String, let value = v as? String { dict[key] = value }
        }
        return dict
    }

    nonisolated static func matchesContentType(_ actual: String?, acceptable: [String]) -> Bool {
        guard let actual else { return false }
        // Strip parameters: "application/json; charset=utf-8" → "application/json"
        let actualType = actual.split(separator: ";").first
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? actual.lowercased()
        for candidate in acceptable {
            let candidateLowered = candidate.lowercased()
            // Exact match
            if actualType == candidateLowered { return true }
            // Wildcard subtype: "text/*" matches "text/plain", "text/html"
            if candidateLowered.hasSuffix("/*") {
                let prefix = candidateLowered.dropLast(2) // drop "/*"
                if actualType.hasPrefix("\(prefix)/") { return true }
            }
            // Universal wildcard: "*/*" matches anything
            if candidateLowered == "*/*" { return true }
        }
        return false
    }

    // MARK: - Private

    private struct RequestStats: Sendable {
        var bytesIn: Int = 0
        var bytesOut: Int = 0
        var statusCode: Int? = nil
    }

    private nonisolated static func extractStatus(from error: NetworkError) -> Int? {
        switch error {
        case .clientError(let r, _), .serverError(let r, _),
             .forbidden(let r), .notFound(let r),
             .unacceptableStatus(let r), .decoding(_, let r),
             .unacceptableContentType(let r, _, _):
            return r.statusCode
        case .unauthorized:
            return 401
        default:
            return nil
        }
    }

    private func reportMetric<E: Endpoint>(
        endpoint: E,
        attempts: Int,
        duration: TimeInterval,
        stats: RequestStats,
        error: NetworkError?
    ) async {
        guard let reporter = configuration.metricsReporter else { return }
        let metric = RequestMetric(
            endpointTypeName: String(describing: E.self),
            method: endpoint.method,
            path: endpoint.path,
            duration: duration,
            attempts: attempts,
            statusCode: stats.statusCode,
            bytesOut: stats.bytesOut,
            bytesIn: stats.bytesIn,
            error: error
        )
        await reporter.record(metric)
    }

    private func sendOnce<E: Endpoint>(
        _ endpoint: E,
        allowRefresh: Bool,
        idempotencyKey: String? = nil
    ) async throws -> (E.Response, RequestStats) {
        var built = try RequestBuilder.build(
            endpoint: endpoint,
            baseURL: configuration.baseURL,
            defaultHeaders: configuration.defaultHeaders,
            encoder: configuration.encoder
        )
        built.request.timeoutInterval = endpoint.timeout ?? configuration.timeout

        // Inject idempotency key if present
        if let key = idempotencyKey {
            built.request.setValue(key, forHTTPHeaderField: endpoint.idempotencyKeyHeaderName)
        }

        let activeAuth = self.activeAuthProvider(for: endpoint)
        if let auth = activeAuth {
            try await auth.apply(to: &built.request, endpoint: endpoint)
        }

        try await interceptors.applyRequest(&built.request, endpoint: endpoint)

        // Capture outbound body size before the request is sent.
        let bytesOut = built.request.httpBody?.count ?? 0

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
                return try await sendOnce(endpoint, allowRefresh: false, idempotencyKey: idempotencyKey)
            case .fail:
                authEventsContinuation.yield(.signedOut)
                throw NetworkError.unauthorized
            }
        }

        guard (200...299).contains(response.statusCode) else {
            throw NetworkError.from(response: response)
        }

        if let acceptable = endpoint.acceptableContentTypes,
           !Self.matchesContentType(response.value(forHeader: "Content-Type"), acceptable: acceptable) {
            throw NetworkError.unacceptableContentType(
                response,
                expected: acceptable,
                actual: response.value(forHeader: "Content-Type")
            )
        }

        let stats = RequestStats(bytesIn: data.count, bytesOut: bytesOut, statusCode: http.statusCode)

        if E.Response.self == Empty.self {
            return (Empty() as! E.Response, stats)
        }
        do {
            let decoded = try endpoint.decodeResponse(from: data, response: response, using: configuration.decoder)
            return (decoded, stats)
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
}
