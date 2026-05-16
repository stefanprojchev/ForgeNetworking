import Testing
import Foundation
@testable import ForgeNetworking

@Suite("NetworkError advanced edge cases")
struct NetworkErrorAdvancedTests {

    private func mk(_ status: Int, body: Data = Data()) -> HTTPResponse {
        HTTPResponse(
            statusCode: status, headers: [:], body: body,
            request: URLRequest(url: URL(string: "https://x.test")!)
        )
    }

    @Test("401 maps to .unauthorized")
    func status401MapsToUnauthorized() {
        let error = NetworkError.from(response: mk(401))
        if case .unauthorized = error {} else {
            Issue.record("Expected .unauthorized, got \(error)")
        }
    }

    @Test("2xx maps to .unacceptableStatus (200 and 299)")
    func twoHundredRangeMapsToUnacceptableStatus() {
        let error200 = NetworkError.from(response: mk(200))
        if case .unacceptableStatus = error200 {} else {
            Issue.record("Expected .unacceptableStatus for 200, got \(error200)")
        }

        let error299 = NetworkError.from(response: mk(299))
        if case .unacceptableStatus = error299 {} else {
            Issue.record("Expected .unacceptableStatus for 299, got \(error299)")
        }
    }

    @Test("3xx maps to .unacceptableStatus (302 and 304)")
    func threeHundredRangeMapsToUnacceptableStatus() {
        let error302 = NetworkError.from(response: mk(302))
        if case .unacceptableStatus(let r) = error302 {
            #expect(r.statusCode == 302)
        } else {
            Issue.record("Expected .unacceptableStatus for 302, got \(error302)")
        }

        let error304 = NetworkError.from(response: mk(304))
        if case .unacceptableStatus(let r) = error304 {
            #expect(r.statusCode == 304)
        } else {
            Issue.record("Expected .unacceptableStatus for 304, got \(error304)")
        }
    }

    @Test("500 with JSON body produces .serverError with decodable payload")
    func fiveHundredWithBodyHasPayload() throws {
        let dto = TestErrorDTO(code: "INTERNAL", message: "oops")
        let body = try JSONEncoder().encode(dto)
        let error = NetworkError.from(response: mk(500, body: body))

        if case .serverError(let response, let payload) = error {
            #expect(response.statusCode == 500)
            let payload = try #require(payload)
            let decoded = try payload.decoded(as: TestErrorDTO.self)
            #expect(decoded.code == "INTERNAL")
            #expect(decoded.message == "oops")
        } else {
            Issue.record("Expected .serverError, got \(error)")
        }
    }

    @Test("500 with empty body produces .serverError with nil payload")
    func fiveHundredWithEmptyBodyHasNilPayload() {
        let error = NetworkError.from(response: mk(500, body: Data()))

        if case .serverError(let response, let payload) = error {
            #expect(response.statusCode == 500)
            #expect(payload == nil)
        } else {
            Issue.record("Expected .serverError, got \(error)")
        }
    }
}
