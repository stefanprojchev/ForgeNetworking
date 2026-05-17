import Foundation

public protocol RequestInterceptor: Sendable {
    func intercept(_ request: inout URLRequest, endpoint: any Endpoint) async throws
}
