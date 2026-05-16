import Testing
import Foundation
import ForgeCore
@testable import ForgeNetworking

private struct EP: Endpoint {
    typealias Body = Empty
    typealias Response = Empty
    var path: String { "/x" }
    var method: HTTPMethod { .get }
}

private struct Boom: Error {}

private struct ThrowingRequestInterceptor: RequestInterceptor {
    func intercept(_ request: inout URLRequest, endpoint: any Endpoint) async throws {
        throw Boom()
    }
}

private struct ThrowingResponseInterceptor: ResponseInterceptor {
    func intercept(_ response: inout HTTPResponse, for endpoint: any Endpoint) async throws {
        throw Boom()
    }
}

private struct OrderRecordingResponseInterceptor: ResponseInterceptor {
    let label: String
    let log: LockedState<[String]>

    func intercept(_ response: inout HTTPResponse, for endpoint: any Endpoint) async throws {
        log.withLock { $0.append(label) }
    }
}

@Suite("InterceptorChain advanced")
struct InterceptorChainAdvancedTests {

    @Test("Throwing request interceptor wraps error as .interceptorFailed")
    func throwingRequestInterceptor() async throws {
        let chain = InterceptorChain(request: [ThrowingRequestInterceptor()], response: [])
        var request = URLRequest(url: URL(string: "https://x.test")!)
        do {
            try await chain.applyRequest(&request, endpoint: EP())
            Issue.record("Expected throw")
        } catch let NetworkError.interceptorFailed(underlying) {
            #expect(underlying is Boom)
        } catch {
            Issue.record("Expected NetworkError.interceptorFailed, got \(error)")
        }
    }

    @Test("Throwing response interceptor wraps error as .interceptorFailed")
    func throwingResponseInterceptor() async throws {
        let chain = InterceptorChain(request: [], response: [ThrowingResponseInterceptor()])
        var response = HTTPResponse(
            statusCode: 200, headers: [:], body: Data(),
            request: URLRequest(url: URL(string: "https://x.test")!)
        )
        do {
            try await chain.applyResponse(&response, endpoint: EP())
            Issue.record("Expected throw")
        } catch let NetworkError.interceptorFailed(underlying) {
            #expect(underlying is Boom)
        } catch {
            Issue.record("Expected NetworkError.interceptorFailed, got \(error)")
        }
    }

    @Test("Multiple response interceptors run in chain order")
    func multipleResponseInterceptorsOrder() async throws {
        let log = LockedState<[String]>([])
        let first = OrderRecordingResponseInterceptor(label: "A", log: log)
        let second = OrderRecordingResponseInterceptor(label: "B", log: log)
        let chain = InterceptorChain(request: [], response: [first, second])

        var response = HTTPResponse(
            statusCode: 200, headers: [:], body: Data(),
            request: URLRequest(url: URL(string: "https://x.test")!)
        )
        try await chain.applyResponse(&response, endpoint: EP())

        let recorded = log.withLock { $0 }
        #expect(recorded == ["A", "B"])
    }
}
