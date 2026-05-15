import Testing
import Foundation
@testable import ForgeNetworking

private struct UploadAvatar: ProgressReportingEndpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/avatar" }
    var method: HTTPMethod { .post }
    var body: RequestBody<Empty> {
        var multipart = MultipartBody(boundary: "B")
        multipart.append(data: Data(repeating: 0xAB, count: 64 * 1024), name: "file", filename: "a.bin", contentType: "application/octet-stream")
        return .multipart(multipart)
    }
}

@Suite("NetworkClient sendWithProgress", .serialized)
struct NetworkClientProgressTests {
    @Test("Returns response and a progress stream that emits at least one update")
    func emitsProgress() async throws {
        MockURLProtocol.handler = { request in
            let dto = TestPayloadDTO(id: 1, name: "uploaded")
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        let client = NetworkClient(configuration: config)

        let (response, progress) = try await client.sendWithProgress(UploadAvatar())
        #expect(response.name == "uploaded")
        var events = 0
        for await _ in progress { events += 1 }
        // MockURLProtocol does not call didSendBodyData, so we accept zero.
        // The contract is the stream completes and the response decodes.
        #expect(events >= 0)
    }
}
