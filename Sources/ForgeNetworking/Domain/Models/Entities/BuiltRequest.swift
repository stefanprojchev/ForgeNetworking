import Foundation

public struct BuiltRequest: Sendable {
    public var request: URLRequest
    public let bodyFileURL: URL?  // non-nil for multipart so client can stream upload from disk
}
