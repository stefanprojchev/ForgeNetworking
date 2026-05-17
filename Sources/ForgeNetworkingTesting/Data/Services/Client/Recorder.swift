import Foundation
import ForgeNetworking

public actor Recorder {

    // MARK: - Static

    public struct RecordedRequest: @unchecked Sendable {
        public let endpoint: Any
        public let bodyData: Data?
        public let bodyDescription: String?
    }

    // MARK: - Dependencies

    private var entries: [RecordedRequest] = []

    // MARK: - Init

    public init() {}

    // MARK: - Implementation

    public func record<E: Endpoint>(_ endpoint: E) {
        let (data, desc) = Self.captureBody(endpoint)
        entries.append(RecordedRequest(endpoint: endpoint, bodyData: data, bodyDescription: desc))
    }

    public func requests<E: Endpoint>(of type: E.Type) -> [E] {
        entries.compactMap { $0.endpoint as? E }
    }

    public func allRequests() -> [RecordedRequest] { entries }

    public func clear() { entries.removeAll() }

    /// Returns the encoded body data captured for the most recent call to the given endpoint type, or nil if none.
    public func lastBodyData<E: Endpoint>(for type: E.Type) -> Data? {
        for entry in entries.reversed() {
            if entry.endpoint is E { return entry.bodyData }
        }
        return nil
    }

    /// Decodes the most recent recorded body for an endpoint as the given type.
    public func lastBody<E: Endpoint, T: Decodable>(
        of endpointType: E.Type,
        as bodyType: T.Type,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T? {
        guard let data = lastBodyData(for: endpointType) else { return nil }
        return try decoder.decode(bodyType, from: data)
    }

    // MARK: - Private

    private static func captureBody<E: Endpoint>(_ endpoint: E) -> (Data?, String?) {
        switch endpoint.body {
        case .empty:
            return (nil, "empty")
        case .json(let value):
            let encoder = JSONEncoder()
            return ((try? encoder.encode(value)), "json")
        case .form(let dict):
            var components = URLComponents()
            components.queryItems = dict.map { URLQueryItem(name: $0.key, value: $0.value) }
            return (Data((components.percentEncodedQuery ?? "").utf8), "form")
        case .formItems(let items, _):
            return (nil, "formItems(\(items.count) items)")
        case .multipart:
            return (nil, "multipart")
        case .raw(let data, let contentType):
            return (data, "raw(\(contentType))")
        }
    }
}
