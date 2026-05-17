import Foundation

public struct APIKeyAuthProvider: AuthProvider {

    // MARK: - Static

    public enum Placement: Sendable {
        case header(name: String)
        case query(name: String)
    }

    // MARK: - Dependencies

    public let key: String
    public let placement: Placement

    // MARK: - Init

    public init(key: String, placement: Placement = .header(name: "X-API-Key")) {
        self.key = key
        self.placement = placement
    }

    // MARK: - Implementation

    public func apply(to request: inout URLRequest, endpoint: any Endpoint) async throws {
        switch placement {
        case .header(let name):
            request.setValue(key, forHTTPHeaderField: name)
        case .query(let name):
            guard let url = request.url,
                  var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: name, value: self.key))
            components.queryItems = items
            request.url = components.url
        }
    }
}
