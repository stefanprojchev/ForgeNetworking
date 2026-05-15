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
    case unacceptableStatus(HTTPResponse)
    case interceptorFailed(any Error)
    case retryExhausted(lastError: NetworkError)

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
