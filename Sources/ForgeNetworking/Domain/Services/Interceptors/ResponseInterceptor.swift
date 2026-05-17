import Foundation

public protocol ResponseInterceptor: Sendable {
    func intercept(_ response: inout HTTPResponse, for endpoint: any Endpoint) async throws
}
