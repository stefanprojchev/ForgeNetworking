import Foundation

final class ProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {

    // MARK: - Dependencies

    private let continuation: AsyncStream<TransferProgress>.Continuation

    // MARK: - Init

    init(continuation: AsyncStream<TransferProgress>.Continuation) {
        self.continuation = continuation
    }

    // MARK: - Implementation

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let total: Int64? = totalBytesExpectedToSend > 0 ? totalBytesExpectedToSend : nil
        continuation.yield(TransferProgress(bytesSent: totalBytesSent, totalBytes: total))
    }
}
