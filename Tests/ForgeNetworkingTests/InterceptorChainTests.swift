import Testing
import Foundation
@testable import ForgeNetworking

private struct AddHeader: RequestInterceptor {
    let key: String
    let value: String
    func intercept(_ request: inout URLRequest, endpoint: any Endpoint) async throws {
        request.setValue(value, forHTTPHeaderField: key)
    }
}

private struct StampStatus: ResponseInterceptor {
    func intercept(_ response: inout HTTPResponse, for endpoint: any Endpoint) async throws {
        // For testing: replace status to 999 to verify interceptors run.
        response = HTTPResponse(
            statusCode: 999,
            headers: response.headers,
            body: response.body,
            request: response.request
        )
    }
}

private struct EP: Endpoint {
    typealias Body = Empty
    typealias Response = Empty
    var path: String { "/x" }
    var method: HTTPMethod { .get }
}

@Suite("InterceptorChain")
struct InterceptorChainTests {
    @Test("Request interceptors run in order")
    func requestOrder() async throws {
        let chain = InterceptorChain(
            request: [AddHeader(key: "A", value: "1"), AddHeader(key: "B", value: "2")],
            response: []
        )
        var request = URLRequest(url: URL(string: "https://x.test")!)
        try await chain.applyRequest(&request, endpoint: EP())
        #expect(request.value(forHTTPHeaderField: "A") == "1")
        #expect(request.value(forHTTPHeaderField: "B") == "2")
    }

    @Test("Response interceptors run on the response")
    func responseRuns() async throws {
        let chain = InterceptorChain(request: [], response: [StampStatus()])
        var resp = HTTPResponse(
            statusCode: 200,
            headers: [:],
            body: Data(),
            request: URLRequest(url: URL(string: "https://x.test")!)
        )
        try await chain.applyResponse(&resp, endpoint: EP())
        #expect(resp.statusCode == 999)
    }
}
