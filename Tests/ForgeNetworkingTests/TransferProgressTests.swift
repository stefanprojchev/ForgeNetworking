import Testing
@testable import ForgeNetworking

@Suite("TransferProgress")
struct TransferProgressTests {
    @Test("Computes fraction when total is known")
    func fractionKnown() {
        let p = TransferProgress(bytesSent: 50, totalBytes: 200)
        #expect(p.fractionCompleted == 0.25)
    }

    @Test("Returns nil fraction when total is unknown")
    func fractionUnknown() {
        let p = TransferProgress(bytesSent: 50, totalBytes: nil)
        #expect(p.fractionCompleted == nil)
    }

    @Test("Returns nil when total is zero (avoid divide by zero)")
    func fractionZero() {
        let p = TransferProgress(bytesSent: 0, totalBytes: 0)
        #expect(p.fractionCompleted == nil)
    }
}
