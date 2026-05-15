import Foundation

public struct TransferHandle: Sendable, Hashable {
    public let id: UUID
    public init(id: UUID = UUID()) { self.id = id }
}
