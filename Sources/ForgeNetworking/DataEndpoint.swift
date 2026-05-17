import Foundation

/// Endpoint refinement for raw byte responses (downloads, binary blobs).
public protocol DataEndpoint: Endpoint where Response == Data {}

public extension DataEndpoint {
    func decodeResponse(from data: Data, response: HTTPResponse, using decoder: JSONDecoder) throws -> Data {
        data
    }
}
