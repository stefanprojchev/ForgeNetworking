import Foundation

public protocol Endpoint<Body, Response>: Sendable {
    associatedtype Body: Encodable & Sendable = Empty
    associatedtype Response: Sendable
    associatedtype ErrorPayload: Decodable & Sendable = Empty

    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var body: RequestBody<Body> { get }
    var authentication: AuthenticationMode { get }
    var retryPolicy: RetryPolicy? { get }
    var timeout: TimeInterval? { get }

    func decodeResponse(from data: Data, response: HTTPResponse, using decoder: JSONDecoder) throws -> Response
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

public extension Endpoint where Response: Decodable {
    func decodeResponse(from data: Data, response: HTTPResponse, using decoder: JSONDecoder) throws -> Response {
        try decoder.decode(Response.self, from: data)
    }
}
