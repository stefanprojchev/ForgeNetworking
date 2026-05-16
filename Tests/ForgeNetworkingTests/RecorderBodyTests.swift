import Testing
import Foundation
import ForgeNetworking
import ForgeNetworkingTesting

private struct CreateItem: Endpoint {
    typealias Body = TestPayloadDTO
    typealias Response = TestPayloadDTO
    let payload: TestPayloadDTO
    var path: String { "/items" }
    var method: HTTPMethod { .post }
    var body: RequestBody<TestPayloadDTO> { .json(payload) }
}

private struct GetItem: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    let id: Int
    var path: String { "/items/\(id)" }
    var method: HTTPMethod { .get }
}

@Suite("Recorder body capture")
struct RecorderBodyTests {
    @Test("lastBodyData returns the encoded JSON of the most recent matching call")
    func captureJSON() async throws {
        let mock = MockNetworkClient()
        let dto = TestPayloadDTO(id: 1, name: "alice")
        await mock.stub(CreateItem.self, with: .success(dto))
        _ = try await mock.send(CreateItem(payload: dto))

        let data = await mock.recorder.lastBodyData(for: CreateItem.self)
        #expect(data != nil)
        let decoded = try JSONDecoder().decode(TestPayloadDTO.self, from: data!)
        #expect(decoded == dto)
    }

    @Test("lastBody decodes the captured body to a given type")
    func decodeLastBody() async throws {
        let mock = MockNetworkClient()
        let dto = TestPayloadDTO(id: 7, name: "bob")
        await mock.stub(CreateItem.self, with: .success(dto))
        _ = try await mock.send(CreateItem(payload: dto))

        let decoded = try await mock.recorder.lastBody(of: CreateItem.self, as: TestPayloadDTO.self)
        #expect(decoded == dto)
    }

    @Test("lastBodyData returns nil for endpoint never called")
    func nilForUnsentEndpoint() async {
        let mock = MockNetworkClient()
        let data = await mock.recorder.lastBodyData(for: CreateItem.self)
        #expect(data == nil)
    }

    @Test("Empty-body endpoint records nil body data")
    func emptyBodyEndpoint() async throws {
        let mock = MockNetworkClient()
        await mock.stub(GetItem.self, with: .success(TestPayloadDTO(id: 1, name: "x")))
        _ = try await mock.send(GetItem(id: 1))
        let data = await mock.recorder.lastBodyData(for: GetItem.self)
        #expect(data == nil)
    }

    @Test("allRequests returns RecordedRequest list with body descriptions")
    func allRequests() async throws {
        let mock = MockNetworkClient()
        await mock.stub(CreateItem.self, with: .success(TestPayloadDTO(id: 1, name: "x")))
        await mock.stub(GetItem.self, with: .success(TestPayloadDTO(id: 1, name: "x")))
        _ = try await mock.send(CreateItem(payload: TestPayloadDTO(id: 1, name: "x")))
        _ = try await mock.send(GetItem(id: 2))

        let all = await mock.recorder.allRequests()
        #expect(all.count == 2)
        #expect(all[0].bodyDescription == "json")
        #expect(all[1].bodyDescription == "empty")
    }
}
