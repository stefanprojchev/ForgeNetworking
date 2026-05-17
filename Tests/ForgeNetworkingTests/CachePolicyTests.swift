import Testing
import Foundation
@testable import ForgeNetworking

private struct CachedGet: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/cached" }
    var method: HTTPMethod { .get }
    var cachePolicy: URLRequest.CachePolicy? { .returnCacheDataElseLoad }
}

private struct UncachedGet: Endpoint {
    typealias Body = Empty
    typealias Response = TestPayloadDTO
    var path: String { "/uncached" }
    var method: HTTPMethod { .get }
    // cachePolicy defaults to nil
}

@Suite("Endpoint cachePolicy")
struct CachePolicyTests {
    @Test("Endpoint cachePolicy propagates to URLRequest.cachePolicy")
    func cachePolicyPropagates() throws {
        let built = try RequestBuilder.build(
            endpoint: CachedGet(),
            baseURL: URL(string: "https://x.test")!,
            defaultHeaders: [:],
            encoder: JSONEncoder()
        )
        #expect(built.request.cachePolicy == .returnCacheDataElseLoad)
    }

    @Test("Default cachePolicy (nil) leaves URLRequest at its default")
    func defaultPolicy() throws {
        let built = try RequestBuilder.build(
            endpoint: UncachedGet(),
            baseURL: URL(string: "https://x.test")!,
            defaultHeaders: [:],
            encoder: JSONEncoder()
        )
        #expect(built.request.cachePolicy == .useProtocolCachePolicy)
    }
}
