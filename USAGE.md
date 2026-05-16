# ForgeNetworking — Usage Guide

This guide walks through every common pattern with runnable code. For installation and a one-paragraph overview, see `README.md`.

## Table of contents

1. [Defining endpoints](#defining-endpoints)
2. [Constructing a client](#constructing-a-client)
3. [Query parameters and headers](#query-parameters-and-headers)
4. [Request bodies — JSON, form, raw, multipart](#request-bodies)
5. [Authentication](#authentication)
6. [Auto-refresh on 401](#auto-refresh-on-401)
7. [Interceptors](#interceptors)
8. [Logging with redaction](#logging-with-redaction)
9. [Retry policy](#retry-policy)
10. [Per-endpoint overrides](#per-endpoint-overrides)
11. [Multipart upload with progress](#multipart-upload-with-progress)
12. [Background uploads and downloads](#background-uploads-and-downloads)
13. [Cancellation](#cancellation)
14. [Error handling patterns](#error-handling-patterns)
15. [Custom encoder / decoder](#custom-encoder--decoder)
16. [Per-host concurrency limits](#per-host-concurrency-limits)
17. [Auth event stream](#auth-event-stream)
18. [Testing with MockNetworkClient](#testing-with-mocknetworkclient)

---

## Defining endpoints

Every request is a type conforming to `Endpoint`. The associated types `Body` and `Response` tie request and response DTOs to the route at compile time.

```swift
import ForgeNetworking

struct UserDTO: Codable, Sendable, Equatable {
    let id: String
    let name: String
}

// GET /users/{id} → UserDTO
struct GetUser: Endpoint {
    typealias Body = Empty
    typealias Response = UserDTO

    let id: String
    var path: String { "/users/\(id)" }
    var method: HTTPMethod { .get }
}

// POST /users with JSON body → UserDTO
struct CreateUser: Endpoint {
    typealias Body = UserDTO
    typealias Response = UserDTO

    let payload: UserDTO
    var path: String { "/users" }
    var method: HTTPMethod { .post }
    var body: RequestBody<UserDTO> { .json(payload) }
}

// DELETE /users/{id} → Empty
struct DeleteUser: Endpoint {
    typealias Body = Empty
    typealias Response = Empty

    let id: String
    var path: String { "/users/\(id)" }
    var method: HTTPMethod { .delete }
}
```

`Empty` is a `Codable & Sendable` placeholder for endpoints with no request body or that return no parsed response. When `Body == Empty`, the default `body` of `.empty` is automatically applied — you don't need to declare it.

---

## Constructing a client

```swift
import ForgeNetworking

let client = NetworkClient(configuration: NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!
))

let user = try await client.send(GetUser(id: "42"))
```

`NetworkClient` is an `actor`. Hold a single instance per backend (or per logical service). It's `Sendable` — pass it across actors freely.

A more configured client:

```swift
var config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
config.defaultHeaders = ["Accept": "application/json", "X-Client-Version": "1.4.0"]
config.timeout = 30
config.maxConcurrentRequestsPerHost = 6
let client = NetworkClient(configuration: config)
```

---

## Query parameters and headers

```swift
struct SearchUsers: Endpoint {
    typealias Body = Empty
    typealias Response = [UserDTO]

    let query: String
    let limit: Int

    var path: String { "/users" }
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
    }
    var headers: [String: String] {
        ["X-Request-ID": UUID().uuidString]
    }
}

let results = try await client.send(SearchUsers(query: "alice", limit: 20))
```

Endpoint headers override client `defaultHeaders` on conflict. Empty `queryItems` and `headers` defaults are applied automatically.

---

## Request bodies

`RequestBody<T>` is an enum covering the common encodings:

```swift
// JSON (most common)
var body: RequestBody<UserDTO> { .json(userDTO) }

// URL-encoded form
var body: RequestBody<Empty> {
    .form(["grant_type": "password", "username": "alice", "password": "secret"])
}

// Raw bytes with custom content type
var body: RequestBody<Empty> {
    .raw(xmlData, contentType: "application/xml")
}

// Multipart — see dedicated section
var body: RequestBody<Empty> { .multipart(multipart) }

// Empty body — default for Body == Empty endpoints
var body: RequestBody<Empty> { .empty }
```

---

## Authentication

### Bearer token

```swift
import ForgeNetworking

let store = InMemoryTokenStore(initial: TokenPair(
    accessToken: "eyJhbGciOi...",
    refreshToken: "rt_abc123"
))

let coordinator = RefreshCoordinator { refreshToken in
    // Your refresh implementation. Use a separate "naked" client so
    // refresh requests don't themselves trigger refresh-on-401.
    let refreshed = try await authClient.send(RefreshTokenEndpoint(token: refreshToken))
    return TokenPair(accessToken: refreshed.access, refreshToken: refreshed.refresh)
}

let bearer = BearerAuthProvider(store: store, coordinator: coordinator)

var config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
config.authProvider = bearer
let client = NetworkClient(configuration: config)
```

Use a separate `NetworkClient` for the refresh endpoint itself so that refresh requests don't recurse through the same auth provider. Mark the refresh endpoint with `authentication: .none`.

### Basic auth

```swift
let provider = BasicAuthProvider(username: "alice", password: "p4ssw0rd")
config.authProvider = provider
```

### API key

```swift
// In a header (default: X-API-Key)
config.authProvider = APIKeyAuthProvider(key: "abc123")

// Or in a query parameter
config.authProvider = APIKeyAuthProvider(key: "abc123", placement: .query(name: "api_key"))

// Or a custom header name
config.authProvider = APIKeyAuthProvider(key: "abc123", placement: .header(name: "X-My-Auth"))
```

### Per-endpoint override

Most endpoints inherit `authentication = .inherit`. Override when needed:

```swift
// Login endpoint — explicitly unauthenticated
struct Login: Endpoint {
    typealias Body = LoginRequest
    typealias Response = TokenPair

    let credentials: LoginRequest
    var path: String { "/auth/login" }
    var method: HTTPMethod { .post }
    var body: RequestBody<LoginRequest> { .json(credentials) }
    var authentication: AuthenticationMode { .none }
}

// Webhook endpoint — different auth than the rest of the API
struct SubmitWebhook: Endpoint {
    typealias Body = WebhookPayload
    typealias Response = Empty

    let signer: HMACAuthProvider // your own AuthProvider conforming type
    let payload: WebhookPayload
    var path: String { "/webhooks" }
    var method: HTTPMethod { .post }
    var body: RequestBody<WebhookPayload> { .json(payload) }
    var authentication: AuthenticationMode { .override(signer) }
}
```

---

## Auto-refresh on 401

Wire `BearerAuthProvider` as above. On 401:

1. `NetworkClient` asks the provider to handle the unauthorized response.
2. `BearerAuthProvider.handle(unauthorized:)` delegates to its `RefreshCoordinator`.
3. The coordinator deduplicates concurrent refreshes — if N requests all hit 401 at once, only ONE refresh call fires; the others await the same task.
4. On refresh success: the new tokens are stored, all waiters resume, every original request retries with the new access token (one retry per request, no infinite loop).
5. On refresh failure: the store is cleared, every in-flight request throws `NetworkError.unauthorized`, and `client.authEvents` emits `.signedOut`.

You don't write this flow — it's built into `NetworkClient.send`.

```swift
// Listen for the sign-out event to route to login
Task {
    for await event in client.authEvents {
        switch event {
        case .refreshed:
            // Optional: telemetry
            print("Token refreshed")
        case .signedOut:
            await router.presentLogin()
        case .refreshFailed(let error):
            print("Refresh failed: \(error)")
        }
    }
}
```

---

## Interceptors

`RequestInterceptor` mutates the URLRequest before it's sent. `ResponseInterceptor` mutates the `HTTPResponse` before decoding.

```swift
import ForgeNetworking
import Foundation

struct CorrelationIDInterceptor: RequestInterceptor {
    func intercept(_ request: inout URLRequest, endpoint: any Endpoint) async throws {
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Correlation-Id")
    }
}

struct ServerTimingInterceptor: ResponseInterceptor {
    let onTiming: @Sendable (String) -> Void
    func intercept(_ response: inout HTTPResponse, for endpoint: any Endpoint) async throws {
        if let header = response.value(forHeader: "Server-Timing") {
            onTiming(header)
        }
    }
}

var config = NetworkConfiguration(baseURL: ...)
config.requestInterceptors = [CorrelationIDInterceptor()]
config.responseInterceptors = [ServerTimingInterceptor { print("Timing: \($0)") }]
```

Interceptors run in array order. Auth runs internally before user-supplied request interceptors, so your interceptors see the `Authorization` header in place.

If an interceptor throws, the error is wrapped as `NetworkError.interceptorFailed(error)`.

---

## Logging with redaction

```swift
import ForgeNetworking

let logger = OSLogNetworkLogger(subsystem: "com.example.app", category: "Network")
let logging = LoggingInterceptor(logger: logger, redactor: .default)

var config = NetworkConfiguration(baseURL: ...)
config.requestInterceptors = [logging]
config.responseInterceptors = [logging]
```

`HeaderRedactor.default` redacts `Authorization`, `Cookie`, `Set-Cookie`, `Proxy-Authorization`. Custom redactor:

```swift
let redactor = HeaderRedactor(redactedNames: [
    "Authorization", "X-Api-Key", "X-Session-Token"
])
let logging = LoggingInterceptor(logger: logger, redactor: redactor)
```

Implement your own logger to route elsewhere:

```swift
final class ConsoleLogger: NetworkLogger {
    func log(_ message: String) { print(message) }
}
```

---

## In-app network capture with ForgeNet

For interactive in-app inspection of network calls (request/response bodies, headers, timing, errors) — typical use case is a debug screen in DEBUG builds — use `ForgeNet` from the `ForgeLog` package. It installs as a `URLProtocol` into your session configuration:

```swift
import ForgeLog
import ForgeNetworking

var config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
#if DEBUG
ForgeNet.install(into: config.sessionConfiguration)
#endif
let client = NetworkClient(configuration: config)
```

ForgeNet handles its own redaction, body capture (up to a configurable byte limit), and presentation via `ForgeNetView`. It's a sibling concern — `LoggingInterceptor` in ForgeNetworking is for lightweight always-on logs (request/response status + headers, redacted); ForgeNet is for the deeper debug experience.

Don't enable both `installGlobally()` and `install(into:)` for the same session — they'll double-record.

Add `ForgeLog` (with the `ForgeNet` product) as a dependency of your app target. ForgeNetworking does not depend on ForgeLog — the wiring is at the app layer.

---

## Retry policy

Default policy:

- 3 attempts
- Exponential backoff with jitter (base 0.5s, cap 8s)
- Retryable statuses: 408, 425, 429, 500, 502, 503, 504
- Retryable methods: GET, HEAD, PUT, DELETE, OPTIONS (POST/PATCH **not** retried by default)
- Honors `Retry-After` (delta-seconds and HTTP-date)

Customize globally:

```swift
config.retryPolicy = RetryPolicy(
    maxAttempts: 5,
    backoff: .exponentialWithJitter(base: 1, cap: 30),
    retryableStatuses: [429, 500, 502, 503, 504],
    retryableMethods: [.get, .head, .put, .delete],
    honorsRetryAfter: true
)
```

Disable retries:

```swift
config.retryPolicy = RetryPolicy(maxAttempts: 1)
```

Custom logic:

```swift
config.retryPolicy = RetryPolicy(
    maxAttempts: 3,
    backoff: .exponentialWithJitter(base: 0.5, cap: 8),
    shouldRetry: { error, attempt in
        // Retry idempotency-token-tagged POSTs too
        if case .serverError = error, attempt < 3 { return true }
        return false
    }
)
```

The refresh-on-401 retry is independent of `RetryPolicy` — it always happens at most once per send.

---

## Per-endpoint overrides

Endpoints can override the client's retry policy, timeout, and authentication:

```swift
struct LongPollEvents: Endpoint {
    typealias Body = Empty
    typealias Response = [EventDTO]

    var path: String { "/events" }
    var method: HTTPMethod { .get }

    // This endpoint may legitimately take a while; loosen the client-wide 30s.
    var timeout: TimeInterval? { 120 }

    // Long-poll: don't retry on transport errors, that's app-level handling.
    var retryPolicy: RetryPolicy? { RetryPolicy(maxAttempts: 1) }
}
```

---

## Multipart upload with progress

```swift
import ForgeNetworking
import Foundation

struct UploadAvatar: ProgressReportingEndpoint {
    typealias Body = Empty
    typealias Response = AvatarDTO

    let imageData: Data
    let userID: String

    var path: String { "/users/\(userID)/avatar" }
    var method: HTTPMethod { .post }
    var body: RequestBody<Empty> {
        var multipart = MultipartBody()
        multipart.append(field: "userId", value: userID)
        multipart.append(
            data: imageData,
            name: "avatar",
            filename: "avatar.jpg",
            contentType: "image/jpeg"
        )
        return .multipart(multipart)
    }
}

// Send and observe progress
let (avatar, progress) = try await client.sendWithProgress(
    UploadAvatar(imageData: data, userID: "42")
)

for await update in progress {
    print("Sent \(update.bytesSent) / \(update.totalBytes ?? -1)")
    if let fraction = update.fractionCompleted {
        await MainActor.run { progressBar.value = fraction }
    }
}
```

Large file uploads can pass file URLs instead of `Data` — multipart encoding streams from disk:

```swift
var multipart = MultipartBody()
multipart.append(
    fileURL: largeFileURL,
    name: "file",
    filename: largeFileURL.lastPathComponent,
    contentType: "application/octet-stream"
)
```

---

## Background uploads and downloads

`NetworkClient` is for foreground requests that complete while the app is running. For uploads/downloads that must survive app suspension (large file uploads, video downloads), use `BackgroundTransferClient`.

```swift
import ForgeNetworking

struct UploadVideo: UploadEndpoint {
    typealias Response = UploadReceipt

    let videoID: String
    var path: String { "/videos/\(videoID)/upload" }
    var contentType: String { "video/mp4" }
    var authentication: AuthenticationMode { .inherit }
}

let bgConfig = BackgroundConfiguration(
    identifier: "com.example.app.uploads",
    baseURL: URL(string: "https://api.example.com")!,
    sharedContainerIdentifier: "group.com.example.app",
    authProvider: bearer
)

let backgroundClient = BackgroundTransferClient(configuration: bgConfig)

let handle = try await backgroundClient.upload(
    UploadVideo(videoID: "abc"),
    file: videoFileURL
)

// Observe events for ALL transfers on this client
Task {
    for await event in backgroundClient.events {
        switch event {
        case .progress(let handle, let sent, let total):
            print("\(handle.id): \(sent) / \(total ?? -1)")
        case .completed(let handle, let response, let fileURL):
            print("\(handle.id) done — \(response.statusCode), file: \(fileURL?.path ?? "-")")
        case .failed(let handle, let error, let resumeData):
            print("\(handle.id) failed: \(error)")
            // For downloads, resumeData lets you continue later
        }
    }
}
```

### Resumable downloads

```swift
struct DownloadFile: DownloadEndpoint {
    var path: String { "/files/\(id)" }
    let id: String
}

// Start
let handle = try await backgroundClient.download(DownloadFile(id: "abc"))

// Later, after a failure that carried resumeData:
let resumed = backgroundClient.resumeDownload(from: storedResumeData)
```

### Wiring system completion (App Delegate)

```swift
// In your AppDelegate or SwiftUI App handler
func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
) {
    Task {
        await backgroundClient.handleSystemCompletion(completionHandler)
    }
}
```

To re-attach after the app is relaunched by the OS, construct the client with the same identifier:

```swift
let backgroundClient = BackgroundTransferClient(configuration: BackgroundConfiguration(
    identifier: "com.example.app.uploads", // same as before
    baseURL: ...,
    sharedContainerIdentifier: ...
))
```

---

## Cancellation

Every `send` runs in a `Task` — cancel that Task to cancel the request.

```swift
let task = Task {
    try await client.send(GetUser(id: "42"))
}

// Later, e.g., when the view disappears:
task.cancel()

do {
    let user = try await task.value
} catch is CancellationError {
    print("Cancelled")
} catch let NetworkError.cancelled {
    print("Cancelled mid-flight")
}
```

The underlying `URLSessionTask` is cancelled with the Swift Task.

---

## Error handling patterns

Catch granularly:

```swift
do {
    let user = try await client.send(GetUser(id: "42"))
    show(user)
} catch let NetworkError.notFound(response) {
    showNotFoundUI()
} catch let NetworkError.clientError(_, payload?) {
    // Decode your API's error envelope
    let err = try payload.decoded(as: APIErrorDTO.self)
    showValidationError(err.message)
} catch NetworkError.unauthorized {
    await router.presentLogin()
} catch let NetworkError.transport(urlError) where urlError.code == .notConnectedToInternet {
    showOfflineBanner()
} catch NetworkError.timeout {
    showTimeoutUI()
} catch let NetworkError.retryExhausted(last) {
    showError("Service unavailable: \(last)")
} catch {
    showError("\(error)")
}
```

The error model is exhaustive — every failure path returns a `NetworkError` case (or your interceptor's error wrapped as `.interceptorFailed`).

---

## Custom encoder / decoder

```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
decoder.keyDecodingStrategy = .convertFromSnakeCase

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
encoder.keyEncodingStrategy = .convertToSnakeCase

var config = NetworkConfiguration(baseURL: ...)
config.encoder = encoder
config.decoder = decoder
```

---

## Per-host concurrency limits

```swift
config.maxConcurrentRequestsPerHost = 6 // typical browser default
```

When the limit is reached for a given host, additional `send` calls await an in-flight request to complete. Limits are independent per host — `api.example.com` and `cdn.example.com` get separate quotas. Default: unlimited.

---

## Auth event stream

`NetworkClient.authEvents` is an `AsyncStream<AuthEvent>` that emits:

- `.refreshed` — refresh-on-401 succeeded; the original request was retried
- `.signedOut` — refresh failed or the auth provider rejected; the user must re-authenticate
- `.refreshFailed(error)` — reserved for explicit refresh failures surfaced by custom providers

Subscribe once at app startup:

```swift
let observer = Task {
    for await event in client.authEvents {
        await handleAuthEvent(event)
    }
}
```

The stream's buffering is unbounded, so events queued before you subscribe are still delivered.

---

## Testing with MockNetworkClient

Production code should depend on `NetworkClientProtocol`, not `NetworkClient` directly. Then in tests, inject `MockNetworkClient`.

```swift
// Production code
final class UserService {
    let client: any NetworkClientProtocol
    init(client: any NetworkClientProtocol) { self.client = client }

    func fetchUser(id: String) async throws -> UserDTO {
        try await client.send(GetUser(id: id))
    }
}

// Test
import Testing
import ForgeNetworking
import ForgeNetworkingTesting

@Suite("UserService")
struct UserServiceTests {
    @Test("Fetches and decodes the user")
    func fetchesUser() async throws {
        let mock = MockNetworkClient()
        let expected = UserDTO(id: "42", name: "alice")
        await mock.stub(GetUser.self, with: .success(expected))

        let service = UserService(client: mock)
        let user = try await service.fetchUser(id: "42")

        #expect(user == expected)

        // Verify what was sent
        let sent = await mock.recorder.requests(of: GetUser.self)
        #expect(sent.count == 1)
        #expect(sent.first?.id == "42")
    }

    @Test("Surfaces network errors")
    func surfacesErrors() async {
        let mock = MockNetworkClient()
        await mock.stub(GetUser.self, with: .failure(NetworkError.timeout))

        let service = UserService(client: mock)
        await #expect(throws: NetworkError.self) {
            _ = try await service.fetchUser(id: "42")
        }
    }

    @Test("Sequenced stubs for retry-then-success scenarios")
    func sequencedStubs() async throws {
        let mock = MockNetworkClient()
        await mock.stub(GetUser.self, with: .sequence([
            .failure(NetworkError.timeout),
            .success(UserDTO(id: "42", name: "alice")),
        ]))

        let service = UserService(client: mock)
        // first call fails
        await #expect(throws: NetworkError.self) {
            _ = try await service.fetchUser(id: "42")
        }
        // second call succeeds
        let user = try await service.fetchUser(id: "42")
        #expect(user.name == "alice")
    }
}
```

Mock auth helpers:

```swift
let tokenStore = MockTokenStore(initial: TokenPair(accessToken: "test", refreshToken: "t"))
let authProvider = MockAuthProvider(token: "test")
```

Both live in `ForgeNetworkingTesting`. Add it as a dependency of your test target only:

```swift
.testTarget(
    name: "MyAppTests",
    dependencies: [
        "MyApp",
        .product(name: "ForgeNetworking", package: "ForgeNetworking"),
        .product(name: "ForgeNetworkingTesting", package: "ForgeNetworking"),
    ]
)
```

## Custom URLSession delegate (pinning, redirects, challenges)

For certificate pinning, custom redirect handling, mTLS, or other URLSession-level concerns, supply a delegate via `NetworkConfiguration.sessionDelegate`:

```swift
final class PinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Your pinning logic. Compare challenge.protectionSpace.serverTrust against
        // pinned public keys / certificates, then complete with .useCredential or .cancelAuthenticationChallenge.
        completionHandler(.performDefaultHandling, nil)
    }
}

var config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
config.sessionDelegate = PinningDelegate()
let client = NetworkClient(configuration: config)
```

The delegate must be `Sendable` (or `@unchecked Sendable`). It receives the session-level callbacks; per-task progress callbacks for `sendWithProgress` go to an internal delegate independently.
