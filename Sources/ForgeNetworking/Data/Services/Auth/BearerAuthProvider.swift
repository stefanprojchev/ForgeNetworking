import Foundation

public final class BearerAuthProvider: AuthProvider {

    // MARK: - Dependencies

    public let store: any TokenStore
    public let coordinator: RefreshCoordinator
    public let headerName: String
    public let scheme: String
    public let proactiveRefreshHeadroom: TimeInterval

    // MARK: - Init

    public init(
        store: any TokenStore,
        coordinator: RefreshCoordinator,
        headerName: String = "Authorization",
        scheme: String = "Bearer",
        proactiveRefreshHeadroom: TimeInterval = 30
    ) {
        self.store = store
        self.coordinator = coordinator
        self.headerName = headerName
        self.scheme = scheme
        self.proactiveRefreshHeadroom = proactiveRefreshHeadroom
    }

    // MARK: - Implementation

    public func apply(to request: inout URLRequest, endpoint: any Endpoint) async throws {
        // Proactive refresh: if expiresAt is within headroom, refresh before applying.
        if let pair = await store.current(),
           let expiresAt = pair.expiresAt,
           expiresAt.timeIntervalSinceNow <= proactiveRefreshHeadroom {
            _ = try? await coordinator.refresh(using: store)
        }

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
