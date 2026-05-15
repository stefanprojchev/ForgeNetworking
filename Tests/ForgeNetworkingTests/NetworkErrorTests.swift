import Testing
import Foundation
@testable import ForgeNetworking

@Suite("NetworkError + ErrorPayload")
struct NetworkErrorTests {
    @Test("ErrorPayload decodes its raw bytes on demand")
    func errorPayloadDecodes() throws {
        let json = #"{"code":"E_FOO","message":"bad"}"#
        let payload = ErrorPayload(raw: Data(json.utf8))
        let decoded = try payload.decoded(as: TestErrorDTO.self)
        #expect(decoded.code == "E_FOO")
        #expect(decoded.message == "bad")
    }

    @Test("HTTPResponseToError maps standard statuses")
    func mapping() {
        let req = URLRequest(url: URL(string: "https://x.test")!)
        let mk = { (status: Int) in
            HTTPResponse(statusCode: status, headers: [:], body: Data(), request: req)
        }

        if case .notFound = NetworkError.from(response: mk(404)) {} else { Issue.record("expected notFound") }
        if case .forbidden = NetworkError.from(response: mk(403)) {} else { Issue.record("expected forbidden") }
        if case .clientError = NetworkError.from(response: mk(418)) {} else { Issue.record("expected clientError") }
        if case .serverError = NetworkError.from(response: mk(500)) {} else { Issue.record("expected serverError") }
        if case .unacceptableStatus = NetworkError.from(response: mk(304)) {} else { Issue.record("expected unacceptableStatus") }
    }
}
