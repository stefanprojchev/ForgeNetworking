import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

@Suite("HostConcurrencyGate advanced")
struct HostConcurrencyGateAdvancedTests {

    // MARK: - Test A: Independent limits per host

    @Test("Independent limits per host — acquiring one host does not block another")
    func independentLimitsPerHost() async {
        let gate = HostConcurrencyGate(limit: 1)

        // Acquire host A — now host A is at its limit
        await gate.acquire(host: "A")

        // Acquiring host B should not be blocked by host A
        // Use async let — if it blocks, the test would hang; we accept the risk as the correct behavior is non-blocking
        async let b: Void = gate.acquire(host: "B")
        await b  // Should return promptly

        // Clean up
        await gate.release(host: "A")
        await gate.release(host: "B")
    }

    // MARK: - Test B: Waiters on same host are resumed FIFO

    @Test("Waiters on the same host are resumed in FIFO order")
    func waitersResumedFIFO() async {
        let gate = HostConcurrencyGate(limit: 1)
        let order = LockedState<[Int]>([])

        // Acquire the slot so waiters will queue up
        await gate.acquire(host: "X")

        // Add 3 waiters in order — space their addition so the gate's queue order is deterministic
        await withTaskGroup(of: Void.self) { group in
            for i in 1...3 {
                let capturedI = i
                group.addTask {
                    // Stagger task starts to enforce ordering in the waiter queue
                    try? await Task.sleep(for: .milliseconds(10 * capturedI))
                    await gate.acquire(host: "X")
                    order.withLock { $0.append(capturedI) }
                    await gate.release(host: "X")
                }
            }

            // Wait a bit to let all three tasks reach their acquire calls and queue up
            try? await Task.sleep(for: .milliseconds(100))

            // Release the initial acquire — this should trigger the first waiter (i=1)
            await gate.release(host: "X")

            // Wait for all tasks to complete
            await group.waitForAll()
        }

        let recorded = order.withLock { $0 }
        #expect(recorded == [1, 2, 3], "Expected FIFO order [1,2,3], got \(recorded)")
    }

    // MARK: - Test C: release without acquire is a no-op

    @Test("release without acquire is a no-op — subsequent acquires still respect the limit")
    func releaseWithoutAcquireIsNoOp() async {
        let gate = HostConcurrencyGate(limit: 2)

        // Call release without any acquire — should not corrupt the counter
        await gate.release(host: "X")

        // Should still be able to acquire twice (limit is 2)
        await gate.acquire(host: "X")
        await gate.acquire(host: "X")

        // Third acquire should block. Use a TaskGroup with a deadline to detect blocking.
        let thirdCompleted = LockedState(false)

        await withTaskGroup(of: Void.self) { group in
            // Task that tries to acquire the blocked third slot
            group.addTask {
                await gate.acquire(host: "X")
                thirdCompleted.withLock { $0 = true }
                await gate.release(host: "X")
            }

            // Give the task time to reach the acquire and block
            try? await Task.sleep(for: .milliseconds(50))

            // Verify it hasn't completed (it should be blocked)
            #expect(thirdCompleted.withLock { $0 } == false, "Third acquire should still be blocked")

            // Release twice to let the third acquire proceed
            await gate.release(host: "X")
            await gate.release(host: "X")

            // Wait for all tasks to finish
            await group.waitForAll()
        }

        // After release, the third task should have completed
        #expect(thirdCompleted.withLock { $0 } == true, "Third acquire should have completed after releases")
    }
}
