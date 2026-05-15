import Foundation

public struct BasicAuthProvider: AuthProvider {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public func apply(to request: inout URLRequest, endpoint: any Endpoint) async throws {
        let token = Data("\(username):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
    }
}
