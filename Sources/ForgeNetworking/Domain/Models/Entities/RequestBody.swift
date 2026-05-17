import Foundation

public enum RequestBody<T: Encodable & Sendable>: Sendable {
    case empty
    case json(T)
    case form([String: String])
    case formItems([(String, FormValue)], encoding: FormEncoding)
    case multipart(MultipartBody)
    case raw(Data, contentType: String)
}

public extension RequestBody {
    static func formEncoded(_ items: [(String, FormValue)], encoding: FormEncoding = .duplicateKeys) -> RequestBody<T> {
        .formItems(items, encoding: encoding)
    }
}
