import Testing
import Foundation
@testable import ForgeNetworking

private struct GetItem: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/items/1" }
    var method: HTTPMethod { .get }
}

@Suite("NetworkClient happy path", .serialized)
struct NetworkClientHappyPathTests {
    @Test("Sends GET and decodes JSON response")
    func decodesResponse() async throws {
        MockURLProtocol.handler = { request in
            #expect(request.url?.path == "/items/1")
            let dto = TestPayloadDTO(id: 1, name: "alice")
            let data = try JSONEncoder().encode(dto)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()

        let client = NetworkClient(configuration: config)
        let result = try await client.send(GetItem())
        #expect(result == TestPayloadDTO(id: 1, name: "alice"))
    }
}
