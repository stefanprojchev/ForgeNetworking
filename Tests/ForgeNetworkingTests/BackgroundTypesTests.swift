import Testing
import Foundation
@testable import ForgeNetworking

@Suite("Background transfer types")
struct BackgroundTypesTests {
    @Test("BackgroundConfiguration retains identifier and base URL")
    func config() {
        let config = BackgroundConfiguration(
            identifier: "com.app.bg",
            baseURL: URL(string: "https://x.test")!,
            sharedContainerIdentifier: "group.com.app",
            isDiscretionary: false
        )
        #expect(config.identifier == "com.app.bg")
        #expect(config.baseURL.absoluteString == "https://x.test")
        #expect(config.sharedContainerIdentifier == "group.com.app")
        #expect(config.isDiscretionary == false)
    }

    @Test("TransferHandle has unique identifiers")
    func uniqueHandles() {
        let a = TransferHandle()
        let b = TransferHandle()
        #expect(a.id != b.id)
    }
}
