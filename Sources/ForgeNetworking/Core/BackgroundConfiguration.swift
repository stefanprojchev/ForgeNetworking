import Foundation

public struct BackgroundConfiguration: Sendable {
    public let identifier: String
    public var baseURL: URL
    public var sharedContainerIdentifier: String?
    public var isDiscretionary: Bool
    public var sessionSendsLaunchEvents: Bool
    public var defaultHeaders: [String: String]
    public var authProvider: (any AuthProvider)?

    public init(
        identifier: String,
        baseURL: URL,
        sharedContainerIdentifier: String? = nil,
        isDiscretionary: Bool = false,
        sessionSendsLaunchEvents: Bool = true,
        defaultHeaders: [String: String] = [:],
        authProvider: (any AuthProvider)? = nil
    ) {
        self.identifier = identifier
        self.baseURL = baseURL
        self.sharedContainerIdentifier = sharedContainerIdentifier
        self.isDiscretionary = isDiscretionary
        self.sessionSendsLaunchEvents = sessionSendsLaunchEvents
        self.defaultHeaders = defaultHeaders
        self.authProvider = authProvider
    }

    func sessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.background(withIdentifier: identifier)
        config.sharedContainerIdentifier = sharedContainerIdentifier
        config.isDiscretionary = isDiscretionary
        config.sessionSendsLaunchEvents = sessionSendsLaunchEvents
        return config
    }
}
