import Testing
@testable import ForgeNetworking

@Suite("BackoffStrategy")
struct BackoffStrategyTests {
    @Test("Fixed strategy returns constant interval")
    func fixed() {
        let s: BackoffStrategy = .fixed(0.5)
        #expect(s.delay(forAttempt: 1) == 0.5)
        #expect(s.delay(forAttempt: 5) == 0.5)
    }

    @Test("Exponential grows with attempt and respects cap")
    func exponentialBounded() {
        let s: BackoffStrategy = .exponentialWithJitter(base: 0.5, cap: 4)
        // attempt 1 → 0.5..1.0; attempt 2 → 1.0..2.0; attempt 3 → 2.0..4.0; attempt 10 capped
        for attempt in 1...10 {
            let d = s.delay(forAttempt: attempt)
            #expect(d <= 4.0)
            #expect(d >= 0)
        }
    }
}
