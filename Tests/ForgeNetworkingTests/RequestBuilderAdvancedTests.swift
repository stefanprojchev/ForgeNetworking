import Testing
import Foundation
@testable import ForgeNetworking

@Suite("RequestBuilder advanced")
struct RequestBuilderAdvancedTests {

    // MARK: - Trailing slash baseURL

    private struct UserEndpoint: Endpoint {
        typealias Body = Empty
        typealias Response = Empty
        var path: String { "/users/1" }
        var method: HTTPMethod { .get }
    }

    @Test("baseURL with trailing slash + endpoint path both appear in result")
    func trailingSlashBaseURL() throws {
        let baseURL = URL(string: "https://api.example.com/v1/")!
        let built = try RequestBuilder.build(
            endpoint: UserEndpoint(),
            baseURL: baseURL,
            defaultHeaders: [:],
            encoder: JSONEncoder()
        )
        let urlString = built.request.url?.absoluteString ?? ""
        #expect(urlString.contains("v1"))
        #expect(urlString.contains("users/1"))
    }

    // MARK: - Multipart bodyFileURL

    private struct MultipartEndpoint: Endpoint {
        typealias Body = Empty
        typealias Response = Empty
        var path: String { "/upload" }
        var method: HTTPMethod { .post }
        var body: RequestBody<Empty> {
            var mp = MultipartBody(boundary: "test-boundary")
            mp.append(data: Data("hello".utf8), name: "file", filename: "hello.txt", contentType: "text/plain")
            return .multipart(mp)
        }
    }

    @Test("Multipart endpoint produces bodyFileURL and nil httpBody")
    func multipartBodyFileURL() throws {
        let built = try RequestBuilder.build(
            endpoint: MultipartEndpoint(),
            baseURL: URL(string: "https://x.test")!,
            defaultHeaders: [:],
            encoder: JSONEncoder()
        )
        #expect(built.bodyFileURL != nil)
        #expect(built.request.httpBody == nil)

        // Cleanup temp file
        if let url = built.bodyFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Timeout propagation

    private struct TimedEndpoint: Endpoint {
        typealias Body = Empty
        typealias Response = Empty
        var path: String { "/slow" }
        var method: HTTPMethod { .get }
        var timeout: TimeInterval? { 7.5 }
    }

    @Test("Endpoint timeout propagates to URLRequest.timeoutInterval")
    func timeoutPropagates() throws {
        let built = try RequestBuilder.build(
            endpoint: TimedEndpoint(),
            baseURL: URL(string: "https://x.test")!,
            defaultHeaders: [:],
            encoder: JSONEncoder()
        )
        #expect(built.request.timeoutInterval == 7.5)
    }

    // MARK: - Encoding failure

    private struct ThrowingBody: Encodable, Sendable {
        func encode(to encoder: any Encoder) throws {
            throw EncodingError.invalidValue(
                "boom",
                EncodingError.Context(codingPath: [], debugDescription: "intentional failure")
            )
        }
    }

    private struct ThrowingEndpoint: Endpoint {
        typealias Body = ThrowingBody
        typealias Response = Empty
        var path: String { "/x" }
        var method: HTTPMethod { .post }
        var body: RequestBody<ThrowingBody> { .json(ThrowingBody()) }
    }

    @Test("Encoding failure wraps as NetworkError.encoding")
    func encodingFailureWraps() throws {
        #expect(throws: NetworkError.self) {
            _ = try RequestBuilder.build(
                endpoint: ThrowingEndpoint(),
                baseURL: URL(string: "https://x.test")!,
                defaultHeaders: [:],
                encoder: JSONEncoder()
            )
        }

        do {
            _ = try RequestBuilder.build(
                endpoint: ThrowingEndpoint(),
                baseURL: URL(string: "https://x.test")!,
                defaultHeaders: [:],
                encoder: JSONEncoder()
            )
        } catch let NetworkError.encoding(underlying) {
            #expect(underlying is EncodingError)
        } catch {
            Issue.record("Expected NetworkError.encoding, got \(error)")
        }
    }
}
