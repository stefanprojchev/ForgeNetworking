import Foundation

public enum RequestBody<T: Encodable & Sendable>: Sendable {
    case empty
    case json(T)
    case form([String: String])
    case multipart(MultipartBody)
    case raw(Data, contentType: String)
}
