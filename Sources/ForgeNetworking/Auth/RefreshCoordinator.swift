import Foundation

public actor RefreshCoordinator {
    public typealias RefreshClosure = @Sendable (_ refreshToken: String) async throws -> TokenPair

    private let refreshClosure: RefreshClosure
    private var inFlight: Task<TokenPair, any Error>?

    public init(refresh: @escaping RefreshClosure) {
        self.refreshClosure = refresh
    }

    public func refresh(using store: any TokenStore) async throws -> TokenPair {
        if let existing = inFlight {
            return try await existing.value
        }

        let task = Task<TokenPair, any Error> { [refreshClosure] in
            guard let current = await store.current() else {
                throw NetworkError.unauthorized
            }
            do {
                let new = try await refreshClosure(current.refreshToken)
                await store.set(new)
                return new
            } catch {
                await store.clear()
                throw error
            }
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}
