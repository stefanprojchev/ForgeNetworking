import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

private final class CapturingLogger: NetworkLogger {
    let messages = LockedState<[String]>([])
    func log(_ message: String) {
        messages.withLock { $0.append(message) }
    }
}

private struct EP: Endpoint {
    typealias Body = Empty
    typealias Response = Empty
    var path: String { "/x" }
    var method: HTTPMethod { .get }
}

@Suite("SlowRequestLogger")
struct SlowRequestLoggerTests {
    @Test("Logs when elapsed exceeds threshold")
    func logsWhenSlow() async throws {
        let logger = CapturingLogger()
        let interceptor = SlowRequestLogger(threshold: 0.05, logger: logger)

        var request = URLRequest(url: URL(string: "https://api.example.com/items")!)
        request.httpMethod = "GET"
        try await interceptor.intercept(&request, endpoint: EP())

        // Simulate a slow round trip
        try await Task.sleep(for: .milliseconds(80))

        var response = HTTPResponse(
            statusCode: 200,
            headers: [:],
            body: Data(),
            request: request
        )
        try await interceptor.intercept(&response, for: EP())

        let logs = logger.messages.withLock { $0 }
        #expect(logs.count == 1)
        #expect(logs[0].contains("[slow]"))
        #expect(logs[0].contains("GET"))
        #expect(logs[0].contains("https://api.example.com/items"))
    }

    @Test("Does not log when elapsed is below threshold")
    func doesNotLogWhenFast() async throws {
        let logger = CapturingLogger()
        let interceptor = SlowRequestLogger(threshold: 5.0, logger: logger)

        var request = URLRequest(url: URL(string: "https://api.example.com/items")!)
        try await interceptor.intercept(&request, endpoint: EP())

        var response = HTTPResponse(
            statusCode: 200,
            headers: [:],
            body: Data(),
            request: request
        )
        try await interceptor.intercept(&response, for: EP())

        let logs = logger.messages.withLock { $0 }
        #expect(logs.isEmpty)
    }

    @Test("Handles concurrent requests independently")
    func concurrentRequests() async throws {
        let logger = CapturingLogger()
        let interceptor = SlowRequestLogger(threshold: 0.05, logger: logger)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    var request = URLRequest(url: URL(string: "https://api.example.com/items/\(i)")!)
                    request.httpMethod = "GET"
                    try? await interceptor.intercept(&request, endpoint: EP())
                    try? await Task.sleep(for: .milliseconds(80))
                    var response = HTTPResponse(
                        statusCode: 200, headers: [:], body: Data(), request: request
                    )
                    try? await interceptor.intercept(&response, for: EP())
                }
            }
        }
        let logs = logger.messages.withLock { $0 }
        #expect(logs.count == 5)
    }

    @Test("Response without tracking header is silently ignored")
    func untrackedResponseIgnored() async throws {
        let logger = CapturingLogger()
        let interceptor = SlowRequestLogger(threshold: 0.001, logger: logger)

        // No request-side intercept call → response has no tracking header
        var response = HTTPResponse(
            statusCode: 200, headers: [:], body: Data(),
            request: URLRequest(url: URL(string: "https://api.example.com/items")!)
        )
        try await interceptor.intercept(&response, for: EP())

        let logs = logger.messages.withLock { $0 }
        #expect(logs.isEmpty)
    }
}
