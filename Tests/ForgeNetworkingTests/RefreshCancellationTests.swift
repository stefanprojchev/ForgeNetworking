import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

@Suite("RefreshCoordinator cancellation")
struct RefreshCancellationTests {
    @Test("In-flight refresh is cancelled when all awaiters cancel")
    func cancelsWhenAllAwaitersCancel() async throws {
        let started = LockedState(0)
        let completed = LockedState(0)
        let coordinator = RefreshCoordinator { _ in
            started.withLock { $0 += 1 }
            try await Task.sleep(for: .seconds(5))  // long enough that cancellation matters
            completed.withLock { $0 += 1 }
            return TokenPair(accessToken: "new", refreshToken: "r")
        }
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "old", refreshToken: "r"))

        let t1 = Task {
            try await coordinator.refresh(using: store)
        }
        let t2 = Task {
            try await coordinator.refresh(using: store)
        }

        // Give them time to attach to the shared inFlight task
        try? await Task.sleep(for: .milliseconds(50))
        #expect(started.withLock { $0 } == 1, "refresh closure should have started exactly once")

        t1.cancel()
        t2.cancel()

        // Both Tasks should rapidly throw CancellationError (or a wrapping error from the underlying sleep cancel)
        do { _ = try await t1.value; Issue.record("t1 should have thrown") } catch { /* expected */ }
        do { _ = try await t2.value; Issue.record("t2 should have thrown") } catch { /* expected */ }

        // After both cancelled, the refresh closure's sleep should have been cancelled
        // long before its 5s completion. Wait a beat to confirm completed is still 0.
        try? await Task.sleep(for: .milliseconds(200))
        #expect(completed.withLock { $0 } == 0, "refresh closure should have been cancelled before completing")
    }

    @Test("Partial cancellation: remaining awaiter still gets the refresh result")
    func partialCancellation() async throws {
        let coordinator = RefreshCoordinator { _ in
            try await Task.sleep(for: .milliseconds(200))
            return TokenPair(accessToken: "new", refreshToken: "r")
        }
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "old", refreshToken: "r"))

        let t1 = Task {
            try await coordinator.refresh(using: store)
        }
        let t2 = Task {
            try await coordinator.refresh(using: store)
        }

        try? await Task.sleep(for: .milliseconds(50))
        t1.cancel()

        // t1 throws (or returns — depending on whether it cancelled before resuming)
        do { _ = try await t1.value } catch {}

        // t2 should complete successfully — the shared refresh task isn't cancelled because t2 is still awaiting
        let result = try await t2.value
        #expect(result.accessToken == "new")
    }

    @Test("Subsequent refresh after a cancelled one works")
    func subsequentRefreshWorks() async throws {
        let coordinator = RefreshCoordinator { _ in
            try await Task.sleep(for: .milliseconds(100))
            return TokenPair(accessToken: "second", refreshToken: "r")
        }
        let store = InMemoryTokenStore(initial: TokenPair(accessToken: "old", refreshToken: "r"))

        let t1 = Task { try await coordinator.refresh(using: store) }
        try? await Task.sleep(for: .milliseconds(20))
        t1.cancel()
        do { _ = try await t1.value } catch {}

        // Now do a fresh refresh — should succeed
        let pair = try await coordinator.refresh(using: store)
        #expect(pair.accessToken == "second")
    }
}
