import Foundation
import ForgeNetworking

public struct MockAuthProvider: AuthProvider {
    public let token: String
    public let recovery: AuthRecovery

    public init(token: String, recovery: AuthRecovery = .fail) {
        self.token = token
        self.recovery = recovery
    }

    public func apply(to request: inout URLRequest, endpoint: any Endpoint) async throws {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    public func handle(unauthorized response: HTTPResponse) async throws -> AuthRecovery {
        recovery
    }
}
