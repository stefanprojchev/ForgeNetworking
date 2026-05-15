import Foundation

public enum EncodedBody: Sendable {
    case data(Data)
    case fileURL(URL)

    public var data: Data? {
        if case .data(let d) = self { return d } else { return nil }
    }

    public var fileURL: URL? {
        if case .fileURL(let url) = self { return url } else { return nil }
    }
}

public struct EncodedRequestBody: Sendable {
    public let payload: EncodedBody?
    public let contentType: String?
}

public enum BodyEncoder {
    public static func encode<T>(
        _ body: RequestBody<T>,
        encoder: JSONEncoder
    ) throws -> EncodedRequestBody {
        switch body {
        case .empty:
            return EncodedRequestBody(payload: nil, contentType: nil)

        case .json(let value):
            let data = try encoder.encode(value)
            return EncodedRequestBody(payload: .data(data), contentType: "application/json")

        case .form(let fields):
            var components = URLComponents()
            components.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
            let raw = components.percentEncodedQuery ?? ""
            return EncodedRequestBody(
                payload: .data(Data(raw.utf8)),
                contentType: "application/x-www-form-urlencoded"
            )

        case .multipart(let multipart):
            let url = try multipart.writeToTemporaryFile()
            return EncodedRequestBody(payload: .fileURL(url), contentType: multipart.contentType)

        case .raw(let data, let contentType):
            return EncodedRequestBody(payload: .data(data), contentType: contentType)
        }
    }
}
