import Foundation

public protocol NetworkClientProtocol: Sendable {
    func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response

    func sendWithProgress<E: ProgressReportingEndpoint>(
        _ endpoint: E
    ) async throws -> (E.Response, AsyncStream<TransferProgress>)
}
