import Foundation
import ForgeCore

final class BackgroundSessionDelegate: NSObject,
    URLSessionDataDelegate, URLSessionDownloadDelegate, URLSessionTaskDelegate, @unchecked Sendable {

    // MARK: - Dependencies

    private let continuation: AsyncStream<TransferEvent>.Continuation
    private let handles = LockedState<[Int: TransferHandle]>([:])
    private let buffers = LockedState<[Int: Data]>([:])
    private let systemCompletion = LockedState<(@Sendable () -> Void)?>(nil)

    // MARK: - Init

    init(continuation: AsyncStream<TransferEvent>.Continuation) {
        self.continuation = continuation
    }

    // MARK: - Implementation

    func register(handle: TransferHandle, for taskIdentifier: Int) {
        handles.withLock { $0[taskIdentifier] = handle }
        buffers.withLock { $0[taskIdentifier] = Data() }
    }

    func setSystemCompletion(_ completion: @escaping @Sendable () -> Void) {
        systemCompletion.withLock { $0 = completion }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard let handle = handles.withLock({ $0[task.taskIdentifier] }) else { return }
        let total: Int64? = totalBytesExpectedToSend > 0 ? totalBytesExpectedToSend : nil
        continuation.yield(.progress(handle, sent: totalBytesSent, total: total))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let handle = handles.withLock({ $0[downloadTask.taskIdentifier] }) else { return }
        let total: Int64? = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
        continuation.yield(.progress(handle, sent: totalBytesWritten, total: total))
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffers.withLock { $0[dataTask.taskIdentifier, default: Data()].append(data) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let handle = handles.withLock({ $0[downloadTask.taskIdentifier] }) else { return }
        // Move to a stable temp location so the caller can read it after this delegate returns.
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("forgenet-download-\(UUID().uuidString)")
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            let response = downloadTask.response as? HTTPURLResponse
            let httpResponse = HTTPResponse(
                statusCode: response?.statusCode ?? 0,
                headers: NetworkClient.headers(from: response ?? HTTPURLResponse()),
                body: Data(),
                request: downloadTask.originalRequest ?? URLRequest(url: dest)
            )
            continuation.yield(.completed(handle, response: httpResponse, fileURL: dest))
        } catch {
            continuation.yield(.failed(handle, .transport(URLError(.cannotMoveFile)), resumeData: nil))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let handle = handles.withLock({ $0[task.taskIdentifier] }) else { return }
        defer { _ = handles.withLock { $0.removeValue(forKey: task.taskIdentifier) } }

        if let urlError = error as? URLError {
            let resumeData = (urlError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data)
            let mapped: NetworkError = {
                switch urlError.code {
                case .timedOut: return .timeout
                case .cancelled: return .cancelled
                default: return .transport(urlError)
                }
            }()
            continuation.yield(.failed(handle, mapped, resumeData: resumeData))
            return
        }
        // For data tasks, deliver accumulated body.
        if task is URLSessionDataTask, let response = task.response as? HTTPURLResponse {
            let body = buffers.withLock { $0.removeValue(forKey: task.taskIdentifier) ?? Data() }
            let httpResponse = HTTPResponse(
                statusCode: response.statusCode,
                headers: NetworkClient.headers(from: response),
                body: body,
                request: task.originalRequest ?? URLRequest(url: response.url ?? URL(string: "about:blank")!)
            )
            continuation.yield(.completed(handle, response: httpResponse, fileURL: nil))
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        if let completion = systemCompletion.withLock({ $0 }) {
            DispatchQueue.main.async { completion() }
            systemCompletion.withLock { $0 = nil }
        }
    }
}
