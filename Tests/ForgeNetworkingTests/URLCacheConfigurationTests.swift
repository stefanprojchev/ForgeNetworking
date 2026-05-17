import Testing
import Foundation
@testable import ForgeNetworking

@Suite("NetworkConfiguration urlCache wiring")
struct URLCacheConfigurationTests {
    @Test("urlCache property defaults to nil")
    func defaultsToNil() {
        let config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        #expect(config.urlCache == nil)
    }

    @Test("Custom URLCache is stored on configuration")
    func customCacheStored() {
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        let cache = URLCache(memoryCapacity: 4_000_000, diskCapacity: 0, diskPath: nil)
        config.urlCache = cache
        #expect(config.urlCache === cache)
    }

    @Test("NetworkClient init copies sessionConfiguration so caller's config is not mutated")
    func sessionConfigurationCopied() {
        var config = NetworkConfiguration(baseURL: URL(string: "https://x.test")!)
        config.sessionConfiguration = URLSessionConfiguration.ephemeral
        config.urlCache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 0, diskPath: nil)
        let originalCacheReference = config.sessionConfiguration.urlCache

        _ = NetworkClient(configuration: config)
        // Caller's sessionConfiguration.urlCache should be unchanged (we copy internally)
        #expect(config.sessionConfiguration.urlCache === originalCacheReference)
    }
}
