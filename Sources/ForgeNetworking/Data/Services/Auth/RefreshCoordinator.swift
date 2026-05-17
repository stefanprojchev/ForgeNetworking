import Foundation

public actor RefreshCoordinator {

    // MARK: - Static

    public typealias RefreshClosure = @Sendable (_ refreshToken: String) async throws -> TokenPair

    // MARK: - Dependencies

    private let refreshClosure: RefreshClosure
    private var inFlight: Task<TokenPair, any Error>?
    private var liveAwaiters: Int = 0
    private var cancellationCount: Int = 0

    // MARK: - Init

    public init(refresh: @escaping RefreshClosure) {
        self.refreshClosure = refresh
    }

    // MARK: - Implementation

    public func refresh(using store: any TokenStore) async throws -> TokenPair {
        let task = ensureInFlight(using: store)
        liveAwaiters += 1

        do {
            let value = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                Task { await self.awaiterCancelled() }
            }
            decrementAwaiter()
            return value
        } catch {
            decrementAwaiter()
            throw error
        }
    }

    // MARK: - Private

    private func ensureInFlight(using store: any TokenStore) -> Task<TokenPair, any Error> {
        if let task = inFlight { return task }
        let task = Task<TokenPair, any Error> { [refreshClosure] in
            guard let current = await store.current() else {
                throw NetworkError.unauthorized
            }
            do {
                let new = try await refreshClosure(current.refreshToken)
                await store.set(new)
                return new
            } catch {
                // Only clear the store on genuine refresh failures, not on Task cancellation.
                if !(error is CancellationError) {
                    await store.clear()
                }
                throw error
            }
        }
        inFlight = task
        return task
    }

    /// Called when one awaiter's Task is cancelled. If all current awaiters have
    /// reported cancellation, the underlying refresh task is cancelled too.
    private func awaiterCancelled() {
        cancellationCount += 1
        if cancellationCount >= liveAwaiters {
            inFlight?.cancel()
        }
    }

    private func decrementAwaiter() {
        liveAwaiters -= 1
        if liveAwaiters == 0 {
            inFlight = nil
            cancellationCount = 0
        }
    }
}
