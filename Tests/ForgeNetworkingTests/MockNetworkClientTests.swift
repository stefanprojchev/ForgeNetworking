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

@Suite("MockNetworkClient")
struct MockNetworkClientTests {
    @Test("Returns stubbed success and records the request")
    func successStub() async throws {
        let mock = MockNetworkClient()
        let dto = TestPayloadDTO(id: 7, name: "x")
        await mock.stub(GetItem.self, with: .success(dto))

        let result = try await mock.send(GetItem(id: 7))
        #expect(result == dto)

        let recorded = await mock.recorder.requests(of: GetItem.self)
        #expect(recorded.count == 1)
        #expect(recorded.first?.id == 7)
    }

    @Test("Returns stubbed failure")
    func failureStub() async {
        let mock = MockNetworkClient()
        await mock.stub(GetItem.self, with: .failure(NetworkError.timeout))
        await #expect(throws: NetworkError.self) {
            _ = try await mock.send(GetItem(id: 1))
        }
    }

    @Test("Sequenced stubs return successive values")
    func sequenced() async throws {
        let mock = MockNetworkClient()
        await mock.stub(GetItem.self, with: .sequence([
            .success(TestPayloadDTO(id: 1, name: "a")),
            .success(TestPayloadDTO(id: 2, name: "b")),
        ]))
        let r1 = try await mock.send(GetItem(id: 99))
        let r2 = try await mock.send(GetItem(id: 99))
        #expect(r1.name == "a")
        #expect(r2.name == "b")
    }

    @Test("Throws when no stub is configured")
    func unstubbed() async {
        let mock = MockNetworkClient()
        await #expect(throws: MockNetworkClient.UnstubbedEndpointError.self) {
            _ = try await mock.send(GetItem(id: 1))
        }
    }
}
