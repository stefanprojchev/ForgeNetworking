public enum HTTPMethod: Sendable, Hashable {
    case get
    case head
    case post
    case put
    case patch
    case delete
    case options
    case trace
    case connect
    case custom(String)

    public var rawValue: String {
        switch self {
        case .get: return "GET"
        case .head: return "HEAD"
        case .post: return "POST"
        case .put: return "PUT"
        case .patch: return "PATCH"
        case .delete: return "DELETE"
        case .options: return "OPTIONS"
        case .trace: return "TRACE"
        case .connect: return "CONNECT"
        case .custom(let value): return value
        }
    }

    /// Per RFC 9110: GET, HEAD, OPTIONS, TRACE, PUT, DELETE are idempotent.
    public var isIdempotent: Bool {
        switch self {
        case .get, .head, .options, .trace, .put, .delete: return true
        case .post, .patch, .connect, .custom: return false
        }
    }
}
