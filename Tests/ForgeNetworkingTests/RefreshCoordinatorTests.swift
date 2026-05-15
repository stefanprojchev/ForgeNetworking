import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

@Suite("RefreshCoordinator")
struct RefreshCoordinatorTests {
    @Test("Concurrent refresh requests trigger refresh closure exactly once")
    func deduplicates() async throws {
        let callCount = LockedState(0)
        let coordinator = RefreshCoordinator { _ in
            callCount.withLock { $0 += 1 }
            try? await Task.sleep(for: .milliseconds(50))
            return TokenPair(accessToken: "new", refreshToken: "newR")
        }
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "old", refreshToken: "oldR"))

        async let r1: TokenPair = coordinator.refresh(using: store)
        async let r2: TokenPair = coordinator.refresh(using: store)
        async let r3: TokenPair = coordinator.refresh(using: store)
        let pairs = try await [r1, r2, r3]

        #expect(callCount.withLock { $0 } == 1)
        for p in pairs { #expect(p.accessToken == "new") }
        let stored = await store.current()
        #expect(stored?.accessToken == "new")
    }

    @Test("Refresh failure clears the store and propagates the error")
    func failureClears() async {
        struct Fail: Error {}
        let coordinator = RefreshCoordinator { _ -> TokenPair in throw Fail() }
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "old", refreshToken: "oldR"))

        await #expect(throws: Fail.self) {
            _ = try await coordinator.refresh(using: store)
        }
        let stored = await store.current()
        #expect(stored == nil)
    }

    @Test("Refresh fails when store has no refresh token")
    func noToken() async {
        let coordinator = RefreshCoordinator { _ in
            TokenPair(accessToken: "x", refreshToken: "y")
        }
        let store = InMemoryTokenStore()
        await #expect(throws: NetworkError.self) {
            _ = try await coordinator.refresh(using: store)
        }
    }
}
