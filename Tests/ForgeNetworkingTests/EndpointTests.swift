import Testing
import Foundation
@testable import ForgeNetworking

@Suite("Endpoint defaults")
struct EndpointTests {
    private struct GetItem: Endpoint {
        typealias Body = Empty
        typealias Response = TestPayloadDTO
        let id: Int
        var path: String { "/items/\(id)" }
        var method: HTTPMethod { .get }
    }

    @Test("Defaults are applied")
    func defaults() {
        let ep = GetItem(id: 7)
        #expect(ep.queryItems.isEmpty)
        #expect(ep.headers.isEmpty)
        if case .empty = ep.body {} else { Issue.record("expected empty body") }
        if case .inherit = ep.authentication {} else { Issue.record("expected inherit auth") }
        #expect(ep.retryPolicy == nil)
        #expect(ep.timeout == nil)
    }
}
