import Foundation

public enum TransferEvent: Sendable {
    case progress(TransferHandle, sent: Int64, total: Int64?)
    case completed(TransferHandle, response: HTTPResponse, fileURL: URL?)
    case failed(TransferHandle, NetworkError, resumeData: Data?)
}
