import Foundation

public struct InterceptorChain: Sendable {

    // MARK: - Dependencies

    public let request: [any RequestInterceptor]
    public let response: [any ResponseInterceptor]

    // MARK: - Init

    public init(request: [any RequestInterceptor], response: [any ResponseInterceptor]) {
        self.request = request
        self.response = response
    }

    // MARK: - Implementation

    public func applyRequest(_ urlRequest: inout URLRequest, endpoint: any Endpoint) async throws {
        for interceptor in request {
            do { try await interceptor.intercept(&urlRequest, endpoint: endpoint) }
            catch { throw NetworkError.interceptorFailed(error) }
        }
    }

    public func applyResponse(_ response: inout HTTPResponse, endpoint: any Endpoint) async throws {
        for interceptor in self.response {
            do { try await interceptor.intercept(&response, for: endpoint) }
            catch { throw NetworkError.interceptorFailed(error) }
        }
    }
}
