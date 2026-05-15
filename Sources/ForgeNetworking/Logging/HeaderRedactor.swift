import Foundation

public struct HeaderRedactor: Sendable {
    public let redactedNames: Set<String>
    public let mask: String

    public init(redactedNames: Set<String>, mask: String = "***") {
        self.redactedNames = Set(redactedNames.map { $0.lowercased() })
        self.mask = mask
    }

    public static let `default` = HeaderRedactor(redactedNames: [
        "authorization",
        "cookie",
        "set-cookie",
        "proxy-authorization",
    ])

    public func redact(headerName: String, value: String) -> String {
        redactedNames.contains(headerName.lowercased()) ? mask : value
    }
}
