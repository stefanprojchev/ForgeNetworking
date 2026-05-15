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
        var built = try RequestBuilder.build(
            endpoint: endpoint,
            baseURL: configuration.baseURL,
            defaultHeaders: configuration.defaultHeaders,
            encoder: configuration.encoder
        )
        built.request.timeoutInterval = endpoint.timeout ?? configuration.timeout

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

    public func sendWithProgress<E: ProgressReportingEndpoint>(
        _ endpoint: E
    ) async throws -> (E.Response, AsyncStream<TransferProgress>) {
        // Implemented in Task 29.
        fatalError("sendWithProgress is implemented in Task 29")
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
