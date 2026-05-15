import Testing
import Foundation
@testable import ForgeNetworking

@Suite("MultipartBody")
struct MultipartBodyTests {
    @Test("Encodes form fields and data parts to a temp file with the correct content-type")
    func encodesToTempFile() throws {
        var body = MultipartBody(boundary: "BOUNDARY")
        body.append(field: "name", value: "stefan")
        body.append(data: Data("hello".utf8), name: "file", filename: "f.txt", contentType: "text/plain")

        let url = try body.writeToTemporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written.contains("--BOUNDARY\r\n"))
        #expect(written.contains("Content-Disposition: form-data; name=\"name\"\r\n\r\nstefan\r\n"))
        #expect(written.contains("Content-Disposition: form-data; name=\"file\"; filename=\"f.txt\"\r\nContent-Type: text/plain\r\n\r\nhello\r\n"))
        #expect(written.hasSuffix("--BOUNDARY--\r\n"))

        #expect(body.contentType == "multipart/form-data; boundary=BOUNDARY")
    }

    @Test("Default boundary is unique per instance")
    func defaultBoundaryUnique() {
        let a = MultipartBody()
        let b = MultipartBody()
        #expect(a.boundary != b.boundary)
    }
}
