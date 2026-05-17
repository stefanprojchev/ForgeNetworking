import Testing
import Foundation
@testable import ForgeNetworking

// Endpoints under test

private struct GetJSON: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/json" }
    var method: HTTPMethod { .get }
    var acceptableContentTypes: [String]? { ["application/json"] }
}

private struct GetText: StringEndpoint {
    typealias Body = Empty
    var path: String { "/text" }
    var method: HTTPMethod { .get }
    var acceptableContentTypes: [String]? { ["text/*"] }
}

private struct GetAnything: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/anything" }
    var method: HTTPMethod { .get }
    var acceptableContentTypes: [String]? { ["*/*"] }
}

private struct GetUnvalidated: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/x" }
    var method: HTTPMethod { .get }
    // acceptableContentTypes not declared — defaults to nil (no validation)
}

@Suite("Content-Type validation", .serialized)
struct ContentTypeValidationTests {

    private func client(handler: @escaping MockURLProtocol.Handler) -> NetworkClient {
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = MockURLProtocol.sessionConfiguration(handler: handler)
        return NetworkClient(configuration: config)
    }

    // MARK: - Static helper unit tests (don't need URLSession)

    @Test("matchesContentType handles exact match")
    func exactMatch() {
        #expect(NetworkClient.matchesContentType("application/json", acceptable: ["application/json"]))
        #expect(!NetworkClient.matchesContentType("text/html", acceptable: ["application/json"]))
    }

    @Test("matchesContentType strips parameters (charset)")
    func stripsParameters() {
        #expect(NetworkClient.matchesContentType("application/json; charset=utf-8", acceptable: ["application/json"]))
        #expect(NetworkClient.matchesContentType("application/json;charset=utf-8", acceptable: ["application/json"]))
    }

    @Test("matchesContentType is case-insensitive")
    func caseInsensitive() {
        #expect(NetworkClient.matchesContentType("Application/JSON", acceptable: ["application/json"]))
        #expect(NetworkClient.matchesContentType("application/json", acceptable: ["APPLICATION/JSON"]))
    }

    @Test("matchesContentType handles wildcard subtypes (text/*)")
    func wildcardSubtype() {
        #expect(NetworkClient.matchesContentType("text/plain", acceptable: ["text/*"]))
        #expect(NetworkClient.matchesContentType("text/html", acceptable: ["text/*"]))
        #expect(!NetworkClient.matchesContentType("application/json", acceptable: ["text/*"]))
    }

    @Test("matchesContentType handles universal wildcard")
    func universalWildcard() {
        #expect(NetworkClient.matchesContentType("application/octet-stream", acceptable: ["*/*"]))
    }

    @Test("matchesContentType returns false for nil actual")
    func nilActual() {
        #expect(!NetworkClient.matchesContentType(nil, acceptable: ["application/json"]))
    }

    @Test("matchesContentType matches one of multiple candidates")
    func multipleAcceptable() {
        #expect(NetworkClient.matchesContentType("text/html", acceptable: ["application/json", "text/html"]))
    }

    // MARK: - End-to-end tests through NetworkClient

    @Test("Server returns JSON for JSON-expecting endpoint — succeeds")
    func jsonForJsonSucceeds() async throws {
        let dto = TestPayloadDTO(id: 1, name: "ok")
        let result = try await client { request in
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!, data)
        }.send(GetJSON())
        #expect(result == dto)
    }

    @Test("Server returns HTML for JSON-expecting endpoint — throws unacceptableContentType")
    func htmlForJsonThrows() async {
        do {
            _ = try await client { request in
                (HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil,
                    headerFields: ["Content-Type": "text/html"]
                )!, Data("<html><body>captive portal</body></html>".utf8))
            }.send(GetJSON())
            Issue.record("expected throw")
        } catch let NetworkError.unacceptableContentType(_, expected, actual) {
            #expect(expected == ["application/json"])
            #expect(actual == "text/html")
        } catch {
            Issue.record("expected unacceptableContentType, got \(error)")
        }
    }

    @Test("Server returns no Content-Type header — throws unacceptableContentType with nil actual")
    func missingContentTypeThrows() async {
        do {
            _ = try await client { request in
                (HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil,
                    headerFields: nil
                )!, Data())
            }.send(GetJSON())
            Issue.record("expected throw")
        } catch let NetworkError.unacceptableContentType(_, _, actual) {
            #expect(actual == nil)
        } catch {
            Issue.record("expected unacceptableContentType, got \(error)")
        }
    }

    @Test("text/* wildcard accepts text/plain")
    func wildcardEndToEnd() async throws {
        let text = try await client { request in
            (HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "text/plain; charset=utf-8"]
            )!, Data("hello".utf8))
        }.send(GetText())
        #expect(text == "hello")
    }

    @Test("Endpoint without acceptableContentTypes skips validation entirely")
    func unvalidatedEndpointSkips() async throws {
        let dto = TestPayloadDTO(id: 99, name: "any")
        let result = try await client { request in
            let data = try JSONEncoder().encode(dto)
            return (HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/garbage"]
            )!, data)
        }.send(GetUnvalidated())
        #expect(result == dto)
    }

    @Test("4xx errors bypass content-type validation")
    func errorStatusBypassesValidation() async {
        // 4xx should hit status-mapping path BEFORE content-type validation,
        // so the error is .clientError (with whatever body).
        do {
            _ = try await client { request in
                (HTTPURLResponse(
                    url: request.url!, statusCode: 400, httpVersion: nil,
                    headerFields: ["Content-Type": "text/html"]
                )!, Data("<error>".utf8))
            }.send(GetJSON())
            Issue.record("expected throw")
        } catch let NetworkError.clientError(response, _) {
            #expect(response.statusCode == 400)
        } catch {
            Issue.record("expected clientError, got \(error)")
        }
    }
}
