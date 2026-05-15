import Testing
import Foundation
@testable import ForgeNetworking

@Suite("BodyEncoder")
struct BodyEncoderTests {
    @Test("Encodes JSON body and sets content type")
    func json() throws {
        let payload = TestPayloadDTO(id: 1, name: "x")
        let encoded = try BodyEncoder.encode(.json(payload), encoder: JSONEncoder())
        #expect(encoded.contentType == "application/json")
        #expect(encoded.payload != nil)
        let round = try JSONDecoder().decode(TestPayloadDTO.self, from: encoded.payload!.data!)
        #expect(round == payload)
    }

    @Test("Encodes form body with URL-encoded fields")
    func form() throws {
        let body: RequestBody<Empty> = .form(["a": "1", "b": "two words"])
        let encoded = try BodyEncoder.encode(body, encoder: JSONEncoder())
        #expect(encoded.contentType == "application/x-www-form-urlencoded")
        let str = String(data: encoded.payload!.data!, encoding: .utf8)!
        #expect(str.contains("a=1"))
        #expect(str.contains("b=two%20words"))
    }

    @Test("Empty body produces no payload and no content type")
    func empty() throws {
        let encoded = try BodyEncoder.encode(RequestBody<Empty>.empty, encoder: JSONEncoder())
        #expect(encoded.contentType == nil)
        #expect(encoded.payload == nil)
    }

    @Test("Raw body preserves data and caller-supplied content type")
    func raw() throws {
        let data = Data("xml".utf8)
        let encoded = try BodyEncoder.encode(RequestBody<Empty>.raw(data, contentType: "application/xml"), encoder: JSONEncoder())
        #expect(encoded.contentType == "application/xml")
        #expect(encoded.payload?.data == data)
    }
}
