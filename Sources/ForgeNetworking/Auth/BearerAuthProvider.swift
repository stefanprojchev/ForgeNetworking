import Foundation

public final class BearerAuthProvider: AuthProvider {
    public let store: any TokenStore
    public let coordinator: RefreshCoordinator
    public let headerName: String
    public let scheme: String

    public init(
        store: any TokenStore,
        coordinator: RefreshCoordinator,
        headerName: String = "Authorization",
        scheme: String = "Bearer"
    ) {
        self.store = store
        self.coordinator = coordinator
        self.headerName = headerName
        self.scheme = scheme
    }

    public func apply(to request: inout URLRequest, endpoint: any Endpoint) async throws {
        guard let pair = await store.current() else { return }
        request.setValue("\(scheme) \(pair.accessToken)", forHTTPHeaderField: headerName)
    }

    public func handle(unauthorized response: HTTPResponse) async throws -> AuthRecovery {
        do {
            _ = try await coordinator.refresh(using: store)
            return .retry
        } catch {
            return .fail
        }
    }
}
