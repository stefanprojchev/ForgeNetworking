import Foundation

final class ProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let continuation: AsyncStream<TransferProgress>.Continuation

    init(continuation: AsyncStream<TransferProgress>.Continuation) {
        self.continuation = continuation
    }

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
