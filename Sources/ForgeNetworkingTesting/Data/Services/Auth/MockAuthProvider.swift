import Foundation
import ForgeNetworking

public struct MockAuthProvider: AuthProvider {

    // MARK: - Dependencies

    public let token: String
    public let recovery: AuthRecovery

    // MARK: - Init

    public init(token: String, recovery: AuthRecovery = .fail) {
        self.token = token
        self.recovery = recovery
    }

    // MARK: - Implementation

    public func apply(to request: inout URLRequest, endpoint: any Endpoint) async throws {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    public func handle(unauthorized response: HTTPResponse) async throws -> AuthRecovery {
        recovery
    }
}
