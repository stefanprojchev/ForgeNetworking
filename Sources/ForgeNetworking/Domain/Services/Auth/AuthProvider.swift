import Foundation

public protocol AuthProvider: Sendable {
    /// Adds credentials (typically a header) to the outgoing request.
    func apply(to request: inout URLRequest, endpoint: any Endpoint) async throws

    /// Called when the server returns 401. Implementations may refresh credentials and
    /// return `.retry`, or surface the failure with `.fail`.
    func handle(unauthorized response: HTTPResponse) async throws -> AuthRecovery
}

public extension AuthProvider {
    func handle(unauthorized response: HTTPResponse) async throws -> AuthRecovery { .fail }
}
