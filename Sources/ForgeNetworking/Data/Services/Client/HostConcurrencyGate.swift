import Foundation

public actor HostConcurrencyGate {

    // MARK: - Dependencies

    public let limit: Int?

    private var inFlight: [String: Int] = [:]
    private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    // MARK: - Init

    public init(limit: Int?) {
        self.limit = limit
    }

    // MARK: - Implementation

    public func acquire(host: String) async {
        guard let limit else { return }
        let current = inFlight[host, default: 0]
        if current < limit {
            inFlight[host] = current + 1
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiters[host, default: []].append(continuation)
        }
    }

    public func release(host: String) {
        guard limit != nil else { return }
        if var queue = waiters[host], !queue.isEmpty {
            let next = queue.removeFirst()
            waiters[host] = queue
            next.resume()
            return
        }
        let current = inFlight[host, default: 0]
        if current > 0 {
            inFlight[host] = current - 1
        }
    }
}
