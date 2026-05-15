import Testing
import Foundation
@testable import ForgeNetworking

@Suite("NetworkConfiguration")
struct NetworkConfigurationTests {
    @Test("Defaults are sensible")
    func defaults() {
        let config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        #expect(config.defaultHeaders.isEmpty)
        #expect(config.requestInterceptors.isEmpty)
        #expect(config.responseInterceptors.isEmpty)
        #expect(config.authProvider == nil)
        #expect(config.retryPolicy == .default)
        #expect(config.maxConcurrentRequestsPerHost == nil)
        #expect(config.timeout == 60)
    }
}
