import Foundation

public struct HeaderRedactor: Sendable {

    // MARK: - Static

    public static let `default` = HeaderRedactor(redactedNames: [
        "authorization",
        "cookie",
        "set-cookie",
        "proxy-authorization",
    ])

    // MARK: - Dependencies

    public let redactedNames: Set<String>
    public let mask: String

    // MARK: - Init

    public init(redactedNames: Set<String>, mask: String = "***") {
        self.redactedNames = Set(redactedNames.map { $0.lowercased() })
        self.mask = mask
    }

    // MARK: - Implementation

    public func redact(headerName: String, value: String) -> String {
        redactedNames.contains(headerName.lowercased()) ? mask : value
    }
}
