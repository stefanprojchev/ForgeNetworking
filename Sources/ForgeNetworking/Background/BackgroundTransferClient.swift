import Foundation

public actor BackgroundTransferClient {
    public let configuration: BackgroundConfiguration
    private let session: URLSession
    private let delegate: BackgroundSessionDelegate
    private let eventsContinuation: AsyncStream<TransferEvent>.Continuation
    public nonisolated let events: AsyncStream<TransferEvent>

    public init(configuration: BackgroundConfiguration) {
        self.configuration = configuration
        var continuation: AsyncStream<TransferEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventsContinuation = continuation
        let delegate = BackgroundSessionDelegate(continuation: continuation)
        self.delegate = delegate
        self.session = URLSession(
            configuration: configuration.sessionConfiguration(),
            delegate: delegate,
            delegateQueue: nil
        )
    }

    public func upload<E: UploadEndpoint>(_ endpoint: E, file: URL) async throws -> TransferHandle {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(endpoint.path))
        request.httpMethod = endpoint.method.rawValue
        request.setValue(endpoint.contentType, forHTTPHeaderField: "Content-Type")
        for (k, v) in configuration.defaultHeaders { request.setValue(v, forHTTPHeaderField: k) }
        for (k, v) in endpoint.headers { request.setValue(v, forHTTPHeaderField: k) }
        if case .inherit = endpoint.authentication, let auth = configuration.authProvider {
            try await auth.apply(to: &request, endpoint: PassthroughEndpoint())
        } else if case .override(let auth) = endpoint.authentication {
            try await auth.apply(to: &request, endpoint: PassthroughEndpoint())
        }

        let task = session.uploadTask(with: request, fromFile: file)
        let handle = TransferHandle()
        delegate.register(handle: handle, for: task.taskIdentifier)
        task.resume()
        return handle
    }

    public func download<E: DownloadEndpoint>(_ endpoint: E) async throws -> TransferHandle {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(endpoint.path))
        request.httpMethod = endpoint.method.rawValue
        for (k, v) in configuration.defaultHeaders { request.setValue(v, forHTTPHeaderField: k) }
        for (k, v) in endpoint.headers { request.setValue(v, forHTTPHeaderField: k) }
        if case .inherit = endpoint.authentication, let auth = configuration.authProvider {
            try await auth.apply(to: &request, endpoint: PassthroughEndpoint())
        } else if case .override(let auth) = endpoint.authentication {
            try await auth.apply(to: &request, endpoint: PassthroughEndpoint())
        }

        let task = session.downloadTask(with: request)
        let handle = TransferHandle()
        delegate.register(handle: handle, for: task.taskIdentifier)
        task.resume()
        return handle
    }

    public func resumeDownload(from resumeData: Data) -> TransferHandle {
        let task = session.downloadTask(withResumeData: resumeData)
        let handle = TransferHandle()
        delegate.register(handle: handle, for: task.taskIdentifier)
        task.resume()
        return handle
    }

    public func handleSystemCompletion(_ completion: @escaping @Sendable () -> Void) {
        delegate.setSystemCompletion(completion)
    }
}

/// Internal Endpoint stand-in so background paths can call AuthProvider.apply uniformly.
private struct PassthroughEndpoint: Endpoint {
    typealias Body = Empty
    typealias Response = Empty
    var path: String { "" }
    var method: HTTPMethod { .get }
}
