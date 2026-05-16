import Testing
import Foundation
import ForgeNetworking
import ForgeNetworkingTesting

private struct GetItem: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    let id: Int
    var path: String { "/items/\(id)" }
    var method: HTTPMethod { .get }
}

private struct GetItemAlt: Endpoint {
    typealias Body = Empty
    typealias Response = TestErrorDTO
    let id: Int
    var path: String { "/alt-items/\(id)" }
    var method: HTTPMethod { .get }
}

@Suite("MockNetworkClient advanced")
struct MockNetworkClientAdvancedTests {

    @Test("Re-stubbing replaces previous stub")
    func reStubReplacesPrevious() async throws {
        let mock = MockNetworkClient()
        let first = TestPayloadDTO(id: 1, name: "first")
        let second = TestPayloadDTO(id: 2, name: "second")

        await mock.stub(GetItem.self, with: .success(first))
        await mock.stub(GetItem.self, with: .success(second))

        let result = try await mock.send(GetItem(id: 99))
        #expect(result == second)
    }

    @Test("Multiple endpoints stubbed independently return their own values")
    func multipleEndpointsStubbed() async throws {
        let mock = MockNetworkClient()
        let payload = TestPayloadDTO(id: 10, name: "payload")
        let altPayload = TestErrorDTO(code: "E_ALT", message: "alt")

        await mock.stub(GetItem.self, with: .success(payload))
        await mock.stub(GetItemAlt.self, with: .success(altPayload))

        let payloadResult = try await mock.send(GetItem(id: 10))
        #expect(payloadResult == payload)

        let altResult = try await mock.send(GetItemAlt(id: 10))
        #expect(altResult == altPayload)
    }

    @Test("Recorder preserves call order across multiple sends")
    func recorderPreservesOrder() async throws {
        let mock = MockNetworkClient()
        let dto = TestPayloadDTO(id: 0, name: "x")
        // Use a sequence so we can send 3 times
        await mock.stub(GetItem.self, with: .sequence([
            .success(dto),
            .success(dto),
            .success(dto)
        ]))

        _ = try await mock.send(GetItem(id: 1))
        _ = try await mock.send(GetItem(id: 2))
        _ = try await mock.send(GetItem(id: 3))

        let recorded = await mock.recorder.requests(of: GetItem.self)
        #expect(recorded.count == 3)
        #expect(recorded[0].id == 1)
        #expect(recorded[1].id == 2)
        #expect(recorded[2].id == 3)
    }
}
