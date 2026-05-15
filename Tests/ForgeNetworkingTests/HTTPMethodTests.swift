import Testing
@testable import ForgeNetworking

@Suite("HTTPMethod")
struct HTTPMethodTests {
    @Test("Standard methods produce uppercase raw values")
    func rawValues() {
        #expect(HTTPMethod.get.rawValue == "GET")
        #expect(HTTPMethod.post.rawValue == "POST")
        #expect(HTTPMethod.put.rawValue == "PUT")
        #expect(HTTPMethod.patch.rawValue == "PATCH")
        #expect(HTTPMethod.delete.rawValue == "DELETE")
        #expect(HTTPMethod.head.rawValue == "HEAD")
        #expect(HTTPMethod.options.rawValue == "OPTIONS")
        #expect(HTTPMethod.trace.rawValue == "TRACE")
        #expect(HTTPMethod.connect.rawValue == "CONNECT")
    }

    @Test("Custom method preserves caller-supplied value")
    func customMethod() {
        #expect(HTTPMethod.custom("PROPFIND").rawValue == "PROPFIND")
    }

    @Test("Idempotency matches RFC 9110")
    func idempotency() {
        #expect(HTTPMethod.get.isIdempotent)
        #expect(HTTPMethod.head.isIdempotent)
        #expect(HTTPMethod.put.isIdempotent)
        #expect(HTTPMethod.delete.isIdempotent)
        #expect(HTTPMethod.options.isIdempotent)
        #expect(HTTPMethod.trace.isIdempotent)
        #expect(!HTTPMethod.post.isIdempotent)
        #expect(!HTTPMethod.patch.isIdempotent)
        #expect(!HTTPMethod.connect.isIdempotent)
    }
}
