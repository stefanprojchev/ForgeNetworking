import Foundation
import ForgeNetworking

public actor Recorder {
    private var entries: [Any] = []

    public init() {}

    public func record<E: Endpoint>(_ endpoint: E) {
        entries.append(endpoint)
    }

    public func requests<E: Endpoint>(of type: E.Type) -> [E] {
        entries.compactMap { $0 as? E }
    }

    public func clear() {
        entries.removeAll()
    }
}
