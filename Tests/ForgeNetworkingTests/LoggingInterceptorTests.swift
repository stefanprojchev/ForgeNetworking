import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

private struct EP: Endpoint {
    typealias Body = Empty
    typealias Response = Empty
    var path: String { "/x" }
    var method: HTTPMethod { .get }
}

private final class CapturingLogger: NetworkLogger {
    let messages = LockedState<[String]>([])
    func log(_ message: String) {
        messages.withLock { $0.append(message) }
    }
}

@Suite("LoggingInterceptor")
struct LoggingInterceptorTests {
    @Test("Default redactor masks Authorization, Cookie, Set-Cookie, Proxy-Authorization")
    func defaultRedactor() {
        let redactor = HeaderRedactor.default
        #expect(redactor.redact(headerName: "Authorization", value: "Bearer abc") == "***")
        #expect(redactor.redact(headerName: "authorization", value: "Bearer abc") == "***")
        #expect(redactor.redact(headerName: "Cookie", value: "x=y") == "***")
        #expect(redactor.redact(headerName: "Set-Cookie", value: "x=y") == "***")
        #expect(redactor.redact(headerName: "Proxy-Authorization", value: "Basic abc") == "***")
        #expect(redactor.redact(headerName: "Accept", value: "json") == "json")
    }

    @Test("Logging interceptor logs redacted request and response")
    func logsRequestAndResponse() async throws {
        let logger = CapturingLogger()
        let interceptor = LoggingInterceptor(logger: logger, redactor: .default)

        var request = URLRequest(url: URL(string: "https://api.example.com/items")!)
        request.httpMethod = "GET"
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        try await interceptor.intercept(&request, endpoint: EP())

        var response = HTTPResponse(
            statusCode: 200,
            headers: ["Authorization": "Bearer secret", "Content-Type": "application/json"],
            body: Data(),
            request: request
        )
        try await interceptor.intercept(&response, for: EP())

        let logs = logger.messages.withLock { $0 }
        #expect(logs.count == 2)
        #expect(logs[0].contains("GET https://api.example.com/items"))
        #expect(logs[0].contains("Authorization: ***"))
        #expect(!logs[0].contains("secret"))
        #expect(logs[1].contains("200"))
        #expect(logs[1].contains("Authorization: ***"))
    }
}
