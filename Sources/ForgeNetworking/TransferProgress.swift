public struct TransferProgress: Sendable, Equatable {
    public let bytesSent: Int64
    public let totalBytes: Int64?

    public init(bytesSent: Int64, totalBytes: Int64?) {
        self.bytesSent = bytesSent
        self.totalBytes = totalBytes
    }

    public var fractionCompleted: Double? {
        guard let total = totalBytes, total > 0 else { return nil }
        return Double(bytesSent) / Double(total)
    }
}
