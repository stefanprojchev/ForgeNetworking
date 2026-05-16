import Testing
import Foundation
@testable import ForgeNetworking

private struct GetWithTypedError: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    typealias ErrorPayload = TestErrorDTO

    var path: String { "/items/1" }
    var method: HTTPMethod { .get }
}

private struct GetWithoutTypedError: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    // ErrorPayload defaults to Empty

    var path: String { "/items/2" }
    var method: HTTPMethod { .get }
}

@Suite("Typed ErrorPayload")
struct TypedErrorPayloadTests {
    @Test("apiError(for:) decodes a clientError payload as the endpoint's ErrorPayload type")
    func decodesClientErrorPayload() throws {
        let dto = TestErrorDTO(code: "E_X", message: "bad")
        let data = try JSONEncoder().encode(dto)
        let response = HTTPResponse(
            statusCode: 422, headers: [:], body: data,
            request: URLRequest(url: URL(string: "https://x.test")!)
        )
        let error = NetworkError.clientError(response, ForgeNetworking.ErrorPayload(raw: data))

        let decoded = error.apiError(for: GetWithTypedError.self)
        #expect(decoded?.code == "E_X")
        #expect(decoded?.message == "bad")
    }

    @Test("apiError(for:) decodes a serverError payload as the endpoint's ErrorPayload type")
    func decodesServerErrorPayload() throws {
        let dto = TestErrorDTO(code: "E_INTERNAL", message: "boom")
        let data = try JSONEncoder().encode(dto)
        let response = HTTPResponse(
            statusCode: 500, headers: [:], body: data,
            request: URLRequest(url: URL(string: "https://x.test")!)
        )
        let error = NetworkError.serverError(response, ForgeNetworking.ErrorPayload(raw: data))

        let decoded = error.apiError(for: GetWithTypedError.self)
        #expect(decoded?.code == "E_INTERNAL")
    }

    @Test("apiError(for:) returns nil for non-error cases")
    func returnsNilForOther() {
        let error = NetworkError.unauthorized
        let decoded = error.apiError(for: GetWithTypedError.self)
        #expect(decoded == nil)
    }

    @Test("apiError(for:) returns nil when payload is absent")
    func returnsNilWhenPayloadAbsent() {
        let response = HTTPResponse(
            statusCode: 422, headers: [:], body: Data(),
            request: URLRequest(url: URL(string: "https://x.test")!)
        )
        let error = NetworkError.clientError(response, nil)
        let decoded = error.apiError(for: GetWithTypedError.self)
        #expect(decoded == nil)
    }

    @Test("apiError(for:) returns nil when the payload doesn't match the declared type")
    func returnsNilOnDecodeFailure() {
        let data = Data("not the right shape".utf8)
        let response = HTTPResponse(
            statusCode: 422, headers: [:], body: data,
            request: URLRequest(url: URL(string: "https://x.test")!)
        )
        let error = NetworkError.clientError(response, ForgeNetworking.ErrorPayload(raw: data))
        let decoded = error.apiError(for: GetWithTypedError.self)
        #expect(decoded == nil)
    }

    @Test("Endpoint without declared ErrorPayload defaults to Empty — compiles and does not crash")
    func defaultEmptyErrorPayload() throws {
        let response = HTTPResponse(
            statusCode: 422, headers: [:], body: Data("{}".utf8),
            request: URLRequest(url: URL(string: "https://x.test")!)
        )
        let error = NetworkError.clientError(response, ForgeNetworking.ErrorPayload(raw: Data("{}".utf8)))
        // Should compile and not crash. Result depends on Empty's Codable behavior — accept either.
        _ = error.apiError(for: GetWithoutTypedError.self)
    }
}
