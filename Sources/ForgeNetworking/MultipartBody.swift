import Foundation

public struct MultipartBody: Sendable {
    public enum Part: Sendable {
        case field(name: String, value: String)
        case data(Data, name: String, filename: String, contentType: String)
        case fileURL(URL, name: String, filename: String, contentType: String)
    }

    public let boundary: String
    public private(set) var parts: [Part] = []

    public init(boundary: String = "ForgeNet-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    public var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    public mutating func append(field name: String, value: String) {
        parts.append(.field(name: name, value: value))
    }

    public mutating func append(data: Data, name: String, filename: String, contentType: String) {
        parts.append(.data(data, name: name, filename: filename, contentType: contentType))
    }

    public mutating func append(fileURL: URL, name: String, filename: String, contentType: String) {
        parts.append(.fileURL(fileURL, name: name, filename: filename, contentType: contentType))
    }

    /// Writes the encoded multipart payload to a temporary file and returns its URL.
    /// Streams file parts so large uploads don't materialize in memory.
    public func writeToTemporaryFile() throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("forgenet-multipart-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: tempURL) else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { try? handle.close() }

        let boundaryDelim = Data("--\(boundary)\r\n".utf8)
        let boundaryClose = Data("--\(boundary)--\r\n".utf8)
        let crlf = Data("\r\n".utf8)

        for part in parts {
            try handle.write(contentsOf: boundaryDelim)
            switch part {
            case .field(let name, let value):
                let header = "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
                try handle.write(contentsOf: Data(header.utf8))
                try handle.write(contentsOf: Data(value.utf8))
                try handle.write(contentsOf: crlf)

            case .data(let data, let name, let filename, let contentType):
                let header = "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(contentType)\r\n\r\n"
                try handle.write(contentsOf: Data(header.utf8))
                try handle.write(contentsOf: data)
                try handle.write(contentsOf: crlf)

            case .fileURL(let url, let name, let filename, let contentType):
                let header = "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(contentType)\r\n\r\n"
                try handle.write(contentsOf: Data(header.utf8))
                let input = try FileHandle(forReadingFrom: url)
                defer { try? input.close() }
                while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty {
                    try handle.write(contentsOf: chunk)
                }
                try handle.write(contentsOf: crlf)
            }
        }
        try handle.write(contentsOf: boundaryClose)
        return tempURL
    }
}
