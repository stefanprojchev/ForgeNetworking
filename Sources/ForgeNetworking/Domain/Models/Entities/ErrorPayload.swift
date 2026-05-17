import Foundation

public struct ErrorPayload: Sendable {
    public let raw: Data

    public init(raw: Data) { self.raw = raw }

    public func decoded<T: Decodable>(
        as type: T.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        try decoder.decode(type, from: raw)
    }
}
