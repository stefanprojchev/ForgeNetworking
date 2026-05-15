import Testing
import Foundation
@testable import ForgeNetworking

private struct GetItem: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/items/1" }
    var method: HTTPMethod { .get }
}

@Suite("NetworkClient error mapping", .serialized)
struct NetworkClientErrorMappingTests {
    private func client() -> NetworkClient {
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration()
        config.retryPolicy = RetryPolicy(maxAttempts: 1)
        return NetworkClient(configuration: config)
    }

    @Test("404 surfaces .notFound with response")
    func notFound() async {
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            _ = try await client().send(GetItem())
            Issue.record("expected throw")
        } catch let NetworkError.notFound(response) {
            #expect(response.statusCode == 404)
        } catch {
            Issue.record("unexpected \(error)")
        }
    }

    @Test("4xx with body surfaces .clientError with decodable payload")
    func clientErrorPayload() async throws {
        let body = try JSONEncoder().encode(TestErrorDTO(code: "E_VALIDATION", message: "bad"))
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 422, httpVersion: nil, headerFields: nil)!, body)
        }
        do {
            _ = try await client().send(GetItem())
            Issue.record("expected throw")
        } catch let NetworkError.clientError(_, payload?) {
            let dto = try payload.decoded(as: TestErrorDTO.self)
            #expect(dto.code == "E_VALIDATION")
        } catch {
            Issue.record("unexpected \(error)")
        }
    }

    @Test("Decode failure surfaces .decoding with the response")
    func decodeFailure() async {
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("not json".utf8))
        }
        do {
            _ = try await client().send(GetItem())
            Issue.record("expected throw")
        } catch let NetworkError.decoding(_, response) {
            #expect(response.statusCode == 200)
        } catch {
            Issue.record("unexpected \(error)")
        }
    }
}
