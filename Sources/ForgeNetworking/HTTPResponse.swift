import Foundation

public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data
    public let request: URLRequest

    public init(statusCode: Int, headers: [String: String], body: Data, request: URLRequest) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.request = request
    }

    public func value(forHeader name: String) -> String? {
        for (key, value) in headers where key.caseInsensitiveCompare(name) == .orderedSame {
            return value
        }
        return nil
    }
}
