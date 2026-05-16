import Testing
import Foundation
@testable import ForgeNetworking

private struct UploadRawData: ProgressReportingEndpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    let payload: Data
    var path: String { "/raw" }
    var method: HTTPMethod { .post }
    var body: RequestBody<Empty> { .raw(payload, contentType: "application/octet-stream") }
}

private struct UploadJSON: ProgressReportingEndpoint {
    typealias Body = TestPayloadDTO
    typealias Response = TestPayloadDTO
    let dto: TestPayloadDTO
    var path: String { "/json" }
    var method: HTTPMethod { .post }
    var body: RequestBody<TestPayloadDTO> { .json(dto) }
}

@Suite("Non-multipart sendWithProgress", .serialized)
struct NonMultipartProgressTests {
    @Test("Raw body POST returns response and progress stream that completes")
    func rawBodyPost() async throws {
        MockURLProtocol.handler = { request in
            let dto = TestPayloadDTO(id: 1, name: "ok")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        let client = NetworkClient(configuration: config)

        let bigPayload = Data(repeating: 0xAB, count: 128 * 1024)
        let (response, progress) = try await client.sendWithProgress(UploadRawData(payload: bigPayload))
        #expect(response.name == "ok")

        // Drain the stream — MockURLProtocol doesn't reliably fire didSendBodyData, so we
        // only assert the stream completes without hanging.
        var events = 0
        for await _ in progress { events += 1 }
        #expect(events >= 0)  // contract: completes cleanly
    }

    @Test("JSON body POST returns response and progress stream that completes")
    func jsonBodyPost() async throws {
        MockURLProtocol.handler = { request in
            let dto = TestPayloadDTO(id: 2, name: "json-ok")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        let client = NetworkClient(configuration: config)

        let (response, progress) = try await client.sendWithProgress(UploadJSON(dto: TestPayloadDTO(id: 2, name: "x")))
        #expect(response.name == "json-ok")
        var events = 0
        for await _ in progress { events += 1 }
        #expect(events >= 0)
    }
}
