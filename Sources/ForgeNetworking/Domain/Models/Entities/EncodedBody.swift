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
