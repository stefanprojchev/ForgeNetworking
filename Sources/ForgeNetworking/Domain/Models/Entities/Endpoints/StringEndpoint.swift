import Foundation

/// Endpoint refinement for text/plain or text/* responses.
public protocol StringEndpoint: Endpoint where Response == String {}

public extension StringEndpoint {
    func decodeResponse(from data: Data, response: HTTPResponse, using decoder: JSONDecoder) throws -> String {
        String(data: data, encoding: .utf8) ?? ""
    }
}
