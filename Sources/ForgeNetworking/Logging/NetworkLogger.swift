import Foundation
import OSLog

public protocol NetworkLogger: Sendable, AnyObject {
    func log(_ message: String)
}

public final class OSLogNetworkLogger: NetworkLogger {
    private let logger: Logger

    public init(subsystem: String = "com.forge.networking", category: String = "Network") {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    public func log(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }
}
