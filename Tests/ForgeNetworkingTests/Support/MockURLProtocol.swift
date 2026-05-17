import Foundation
import ForgeCore

/// A URLProtocol subclass that returns canned responses for unit testing real URLSession code.
/// Each test gets its own isolated handler via `sessionConfiguration(handler:)`. The handler is
/// keyed by a UUID injected as an HTTP header, so concurrent test suites don't share state.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let headerName = "X-MockURLProtocol-Id"
    private static let registry = LockedState<[String: Handler]>([:])

    /// Build a `URLSessionConfiguration` registered with the given handler.
    /// The handler is invoked for every request issued via the resulting session.
    static func sessionConfiguration(handler: @escaping Handler) -> URLSessionConfiguration {
        let id = UUID().uuidString
        registry.withLock { $0[id] = handler }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.httpAdditionalHeaders = [headerName: id]
        return config
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let id = request.value(forHTTPHeaderField: Self.headerName),
              let handler = Self.registry.withLock({ $0[id] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
