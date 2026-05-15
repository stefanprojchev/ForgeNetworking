import Foundation

/// Endpoint refinement for background downloads. Response is the downloaded file URL.
public protocol DownloadEndpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem] { get }
    var authentication: AuthenticationMode { get }
}

public extension DownloadEndpoint {
    var method: HTTPMethod { .get }
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [] }
    var authentication: AuthenticationMode { .inherit }
}
