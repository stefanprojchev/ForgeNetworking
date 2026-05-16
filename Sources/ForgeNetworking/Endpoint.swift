import Foundation

public protocol Endpoint<Body, Response>: Sendable {
    associatedtype Body: Encodable & Sendable = Empty
    associatedtype Response: Decodable & Sendable
    associatedtype ErrorPayload: Decodable & Sendable = Empty

    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var body: RequestBody<Body> { get }
    var authentication: AuthenticationMode { get }
    var retryPolicy: RetryPolicy? { get }
    var timeout: TimeInterval? { get }
}

public extension Endpoint {
    var queryItems: [URLQueryItem] { [] }
    var headers: [String: String] { [:] }
    var authentication: AuthenticationMode { .inherit }
    var retryPolicy: RetryPolicy? { nil }
    var timeout: TimeInterval? { nil }
}

public extension Endpoint where Body == Empty {
    var body: RequestBody<Empty> { .empty }
}
