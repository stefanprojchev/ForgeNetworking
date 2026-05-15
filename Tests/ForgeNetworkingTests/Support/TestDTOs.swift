import Foundation

struct TestPayloadDTO: Codable, Sendable, Equatable {
    let id: Int
    let name: String
}

struct TestErrorDTO: Codable, Sendable, Equatable {
    let code: String
    let message: String
}
