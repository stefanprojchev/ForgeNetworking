import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

@Suite("HostConcurrencyGate")
struct HostConcurrencyGateTests {
    @Test("Limits concurrent operations per host")
    func limitsConcurrency() async {
        let gate = HostConcurrencyGate(limit: 2)
        let active = LockedState(0)
        let peak = LockedState(0)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await gate.acquire(host: "api.example.com")
                    let now = active.withLock { $0 += 1; return $0 }
                    peak.withLock { $0 = max($0, now) }
                    try? await Task.sleep(for: .milliseconds(20))
                    active.withLock { $0 -= 1 }
                    await gate.release(host: "api.example.com")
                }
            }
        }
        #expect(peak.withLock { $0 } <= 2)
    }

    @Test("Unlimited mode (limit = nil) does not gate")
    func unlimited() async {
        let gate = HostConcurrencyGate(limit: nil)
        for _ in 0..<50 {
            await gate.acquire(host: "api.example.com")
        }
        for _ in 0..<50 {
            await gate.release(host: "api.example.com")
        }
    }
}
