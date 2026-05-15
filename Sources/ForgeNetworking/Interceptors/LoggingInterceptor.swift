import Foundation

public struct LoggingInterceptor: RequestInterceptor, ResponseInterceptor {
    public let logger: any NetworkLogger
    public let redactor: HeaderRedactor

    public init(logger: any NetworkLogger, redactor: HeaderRedactor = .default) {
        self.logger = logger
        self.redactor = redactor
    }

    public func intercept(_ request: inout URLRequest, endpoint: any Endpoint) async throws {
        var lines = ["→ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")"]
        for (k, v) in (request.allHTTPHeaderFields ?? [:]).sorted(by: { $0.key < $1.key }) {
            lines.append("  \(k): \(redactor.redact(headerName: k, value: v))")
        }
        logger.log(lines.joined(separator: "\n"))
    }

    public func intercept(_ response: inout HTTPResponse, for endpoint: any Endpoint) async throws {
        var lines = ["← \(response.statusCode) \(response.request.url?.absoluteString ?? "?")"]
        for (k, v) in response.headers.sorted(by: { $0.key < $1.key }) {
            lines.append("  \(k): \(redactor.redact(headerName: k, value: v))")
        }
        logger.log(lines.joined(separator: "\n"))
    }
}
