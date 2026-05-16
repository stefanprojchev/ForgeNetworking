import Foundation
import ForgeNetworking

public actor MockNetworkClient: NetworkClientProtocol {
    public struct UnstubbedEndpointError: Error, Sendable {
        public let endpointType: String
    }

    private var stubs: [ObjectIdentifier: Any] = [:]
    public let recorder = Recorder()

    public init() {}

    public func stub<E: Endpoint>(_ type: E.Type, with response: StubResponse<E.Response>) {
        stubs[ObjectIdentifier(type)] = response
    }

    public func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response {
        await recorder.record(endpoint)
        return try await pop(E.self)
    }

    public func sendWithProgress<E: ProgressReportingEndpoint>(
        _ endpoint: E
    ) async throws -> (E.Response, AsyncStream<TransferProgress>) {
        await recorder.record(endpoint)
        let response = try await pop(E.self)
        let (stream, continuation) = AsyncStream.makeStream(of: TransferProgress.self)
        continuation.finish()
        return (response, stream)
    }

    public nonisolated func stream<E: Endpoint>(
        _ endpoint: E
    ) async throws -> (HTTPResponse, AsyncThrowingStream<Data, any Error>) {
        await recorder.record(endpoint)
        let response = HTTPResponse(
            statusCode: 200, headers: [:], body: Data(),
            request: URLRequest(url: URL(string: "https://mock.test")!)
        )
        let (dataStream, continuation) = AsyncThrowingStream.makeStream(of: Data.self)
        continuation.finish()
        return (response, dataStream)
    }

    private func pop<E: Endpoint>(_ type: E.Type) async throws -> E.Response {
        let key = ObjectIdentifier(type)
        guard let raw = stubs[key], let stub = raw as? StubResponse<E.Response> else {
            throw UnstubbedEndpointError(endpointType: String(describing: type))
        }
        switch stub {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .sequence(var items):
            guard !items.isEmpty else {
                throw UnstubbedEndpointError(endpointType: String(describing: type))
            }
            let head = items.removeFirst()
            stubs[key] = StubResponse<E.Response>.sequence(items)
            switch head {
            case .success(let value): return value
            case .failure(let error): throw error
            case .sequence:
                throw UnstubbedEndpointError(endpointType: String(describing: type))
            }
        }
    }
}
