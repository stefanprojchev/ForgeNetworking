import Testing
import Foundation
@testable import ForgeNetworking

@Suite("BodyEncoder advanced")
struct BodyEncoderAdvancedTests {

    @Test("Form encodes special characters correctly")
    func formSpecialCharacters() throws {
        let body: RequestBody<Empty> = .form([
            "q": "hello world",
            "filter": "a&b=c+d",
            "name": "café"
        ])
        let encoded = try BodyEncoder.encode(body, encoder: JSONEncoder())
        #expect(encoded.contentType == "application/x-www-form-urlencoded")

        let raw = try #require(encoded.payload?.data)
        let str = try #require(String(data: raw, encoding: .utf8))

        // "hello world" should be percent-encoded (either space→%20 or space→+)
        #expect(str.contains("hello%20world") || str.contains("hello+world"))

        // The literal "&", "=" and "+" inside the value "a&b=c+d" must be encoded —
        // they must not appear unescaped in the *value* position. Since all params are
        // joined by "&" and "=" as delimiters, we check the pair is encoded by verifying
        // the raw string does NOT contain "filter=a&b" (which would mean the & leaked).
        #expect(!str.contains("filter=a&b"))
    }

    @Test("Form with empty dictionary produces empty payload with correct content type")
    func formEmpty() throws {
        let body: RequestBody<Empty> = .form([:])
        let encoded = try BodyEncoder.encode(body, encoder: JSONEncoder())
        #expect(encoded.contentType == "application/x-www-form-urlencoded")
        let raw = try #require(encoded.payload?.data)
        #expect(raw == Data())
    }

    @Test("Raw with empty Data preserves content type and produces empty payload")
    func rawEmptyData() throws {
        let body: RequestBody<Empty> = .raw(Data(), contentType: "application/octet-stream")
        let encoded = try BodyEncoder.encode(body, encoder: JSONEncoder())
        #expect(encoded.contentType == "application/octet-stream")
        let raw = try #require(encoded.payload?.data)
        #expect(raw == Data())
    }
}
