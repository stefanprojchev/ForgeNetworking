# ForgeNetworking

Typed, async/await-first HTTP networking for the Forge package family.

- Type-safe `Endpoint` DSL — every request declares its body and response DTO.
- Pluggable auth: `BearerAuthProvider` with single-flight refresh, `BasicAuthProvider`, `APIKeyAuthProvider`.
- Request/response interceptors with composable chains; logging interceptor with header redaction.
- Idempotency-aware retry with exponential backoff and `Retry-After` honoring.
- Multipart uploads with progress, foreground via `NetworkClient`, background via `BackgroundTransferClient`.
- Per-host concurrency limits, full `Task.cancel()` support.
- Companion `ForgeNetworkingTesting` target with `MockNetworkClient`, stub builders, and recorder.

## Requirements

- Swift 6.3
- iOS 18+ / macOS 15+

## Installation

```swift
.package(url: "https://github.com/stefanprojchev/ForgeNetworking.git", from: "1.0.0")
```

## Quick start

```swift
struct GetUser: Endpoint {
    typealias Body = Empty
    typealias Response = UserDTO
    let id: String
    var path: String { "/users/\(id)" }
    var method: HTTPMethod { .get }
}

let client = NetworkClient(configuration: NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!
))

let user = try await client.send(GetUser(id: "42"))
```

## Auth with auto-refresh

```swift
let store = InMemoryTokenStore(initial: TokenPair(accessToken: "...", refreshToken: "..."))
let coordinator = RefreshCoordinator { refreshToken in
    try await refreshAPI(refreshToken)  // your endpoint
}
let provider = BearerAuthProvider(store: store, coordinator: coordinator)

var config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
config.authProvider = provider
let client = NetworkClient(configuration: config)
```

On 401, the client refreshes once and retries with the new token. Concurrent refreshes are deduplicated.

## Testing

In test targets, depend on `ForgeNetworkingTesting`:

```swift
let mock = MockNetworkClient()
await mock.stub(GetUser.self, with: .success(UserDTO(id: "42", name: "alice")))
let result = try await mock.send(GetUser(id: "42"))
```

## License

MIT — see `LICENSE`.
