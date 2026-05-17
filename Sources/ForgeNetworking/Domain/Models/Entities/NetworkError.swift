import Foundation

public indirect enum NetworkError: Error, Sendable {
    case invalidURL(String)
    case encoding(any Error)
    case transport(URLError)
    case timeout
    case cancelled
    case unauthorized
    case forbidden(HTTPResponse)
    case notFound(HTTPResponse)
    case clientError(HTTPResponse, ErrorPayload?)
    case serverError(HTTPResponse, ErrorPayload?)
    case decoding(any Error, HTTPResponse)
    case unacceptableContentType(HTTPResponse, expected: [String], actual: String?)
    case unacceptableStatus(HTTPResponse)
    case interceptorFailed(any Error)
    case retryExhausted(lastError: NetworkError)

    // NOTE: `ErrorPayload` in the cases below refers to `ForgeNetworking.ErrorPayload` (the raw-data wrapper),
    // not the `Endpoint.ErrorPayload` associated type.

    /// Maps an HTTP response to a `NetworkError`. 2xx callers should not invoke this.
    public static func from(response: HTTPResponse) -> NetworkError {
        let payload = response.body.isEmpty ? nil : ErrorPayload(raw: response.body)
        switch response.statusCode {
        case 200...299:
            return .unacceptableStatus(response) // caller bug: 2xx is not an error
        case 401:
            return .unauthorized
        case 403:
            return .forbidden(response)
        case 404:
            return .notFound(response)
        case 400...499:
            return .clientError(response, payload)
        case 500...599:
            return .serverError(response, payload)
        default:
            return .unacceptableStatus(response)
        }
    }
}

public extension NetworkError {
    /// Attempts to decode the carried error payload as the endpoint's declared `ErrorPayload` type.
    /// Returns `nil` for non-error cases, when the payload is absent, or when decoding fails.
    func apiError<E: Endpoint>(
        for type: E.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) -> E.ErrorPayload? {
        let rawPayload: ForgeNetworking.ErrorPayload?
        switch self {
        case .clientError(_, let p), .serverError(_, let p):
            rawPayload = p
        default:
            return nil
        }
        guard let rawPayload else { return nil }
        return try? rawPayload.decoded(as: E.ErrorPayload.self, using: decoder)
    }
}
