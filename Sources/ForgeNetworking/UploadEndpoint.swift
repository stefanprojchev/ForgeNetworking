import Foundation

/// Endpoint refinement for background uploads. Body is supplied as a file URL at send time,
/// so the conforming endpoint declares only path/method/headers/auth — no inline body.
public protocol UploadEndpoint: Sendable {
    associatedtype Response: Decodable & Sendable

    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var contentType: String { get }
    var queryItems: [URLQueryItem] { get }
    var authentication: AuthenticationMode { get }
}

public extension UploadEndpoint {
    var method: HTTPMethod { .post }
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [] }
    var authentication: AuthenticationMode { .inherit }
}
