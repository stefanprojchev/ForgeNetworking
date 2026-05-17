import Foundation

public enum RequestBuilder {

    // MARK: - Implementation

    public static func build<E: Endpoint>(
        endpoint: E,
        baseURL: URL,
        defaultHeaders: [String: String],
        encoder: JSONEncoder
    ) throws -> BuiltRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        if !endpoint.queryItems.isEmpty {
            let existing = components?.queryItems ?? []
            components?.queryItems = existing + endpoint.queryItems
        }
        guard let url = components?.url else {
            throw NetworkError.invalidURL("\(baseURL.absoluteString)\(endpoint.path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        if let timeout = endpoint.timeout {
            request.timeoutInterval = timeout
        }
        if let policy = endpoint.cachePolicy {
            request.cachePolicy = policy
        }

        // defaults first, then endpoint overrides
        for (k, v) in defaultHeaders { request.setValue(v, forHTTPHeaderField: k) }
        for (k, v) in endpoint.headers { request.setValue(v, forHTTPHeaderField: k) }

        let encoded: EncodedRequestBody
        do {
            encoded = try BodyEncoder.encode(endpoint.body, encoder: encoder)
        } catch {
            throw NetworkError.encoding(error)
        }
        if let contentType = encoded.contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        var bodyFileURL: URL? = nil
        switch encoded.payload {
        case .data(let data):
            request.httpBody = data
        case .fileURL(let url):
            bodyFileURL = url
        case .none:
            break
        }
        return BuiltRequest(request: request, bodyFileURL: bodyFileURL)
    }
}
