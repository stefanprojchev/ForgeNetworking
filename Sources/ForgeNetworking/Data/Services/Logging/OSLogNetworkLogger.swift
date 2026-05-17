import Foundation
import OSLog

public final class OSLogNetworkLogger: NetworkLogger {

    // MARK: - Dependencies

    private let logger: Logger

    // MARK: - Init

    public init(subsystem: String = "com.forge.networking", category: String = "Network") {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    // MARK: - Implementation

    public func log(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }
}
