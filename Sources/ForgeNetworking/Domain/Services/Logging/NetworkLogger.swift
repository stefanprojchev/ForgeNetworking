public protocol NetworkLogger: Sendable, AnyObject {
    func log(_ message: String)
}
