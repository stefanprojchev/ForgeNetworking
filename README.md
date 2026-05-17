# ForgeNetworking

Typed, async/await-first HTTP networking for the Forge package family.

![Swift 6.3+](https://img.shields.io/badge/Swift-6.3+-orange.svg)
![iOS 18+](https://img.shields.io/badge/iOS-18+-blue.svg)
![macOS 15+](https://img.shields.io/badge/macOS-15+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)
[![Release](https://img.shields.io/github/v/release/stefanprojchev/ForgeNetworking)](https://github.com/stefanprojchev/ForgeNetworking/releases)

---

ForgeNetworking is the HTTP layer in the **Forge** family of iOS packages. It centers on a type-safe `Endpoint` DSL — every request declares its body and response DTO — and ships with pluggable auth, idempotency-aware retry, multipart and background transfers, and a first-class testing target.

## Features

- **Type-safe `Endpoint` DSL** — every request declares its body and response DTO.
- **Pluggable auth** — `BearerAuthProvider` with single-flight refresh, `BasicAuthProvider`, `APIKeyAuthProvider`.
- **Composable interceptor chains** for requests and responses, with a logging interceptor that supports header redaction.
- **Idempotency-aware retry** with exponential backoff that honors `Retry-After`.
- **Multipart uploads with progress**, foreground via `NetworkClient`, background via `BackgroundTransferClient`.
- **Per-host concurrency limits** and full `Task.cancel()` support.
- **Three targets** — split so you only link what you need:
  - `ForgeNetworking` — the core client, endpoint DSL, auth, interceptors, retry, multipart.
  - `ForgeNetworkingKeychain` — Keychain-backed `TokenStore` for `BearerAuthProvider`.
  - `ForgeNetworkingTesting` — `MockNetworkClient`, stub builders, and a request recorder.

## Requirements

- **iOS** 18+
- **macOS** 15+
- **Swift** 6.3+ (Xcode 26 or later)

## Installation

### Xcode

1. **File → Add Package Dependencies…**
2. Paste `https://github.com/stefanprojchev/ForgeNetworking.git`
3. Set rule to **Up to Next Major** from `1.0.0`

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/stefanprojchev/ForgeNetworking.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "ForgeNetworking", package: "ForgeNetworking"),
            // Optional — Keychain-backed token store
            .product(name: "ForgeNetworkingKeychain", package: "ForgeNetworking"),
        ]
    ),
    .testTarget(
        name: "YourAppTests",
        dependencies: [
            .product(name: "ForgeNetworkingTesting", package: "ForgeNetworking"),
        ]
    )
]
```

## Quick Start

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

## The Forge Family

ForgeNetworking is part of the **Forge** family of Swift packages for iOS.

| Package | Description |
|---|---|
| [ForgeCore](https://github.com/stefanprojchev/ForgeCore) | Thread-safe primitives for iOS Swift packages. |
| [ForgeInject](https://github.com/stefanprojchev/ForgeInject) | Dependency injection with constructor and property wrapper support. |
| [ForgeObservers](https://github.com/stefanprojchev/ForgeObservers) | Reactive system observers — connectivity, lifecycle, keyboard, and more. |
| [ForgeStorage](https://github.com/stefanprojchev/ForgeStorage) | Type-safe key-value, file, and Keychain storage. |
| [ForgeDB](https://github.com/stefanprojchev/ForgeDB) | Type-safe repository pattern and GRDB-backed SQLite persistence. |
| [ForgeOrchestrator](https://github.com/stefanprojchev/ForgeOrchestrator) | Orchestrate app flows — startup gates, data pipelines, and continuous monitors. |
| [ForgePush](https://github.com/stefanprojchev/ForgePush) | Push notification management — permissions, tokens, and routing. |
| [ForgeLocation](https://github.com/stefanprojchev/ForgeLocation) | Location triggers — geofencing, significant changes, and visits. |
| [ForgeBackgroundTasks](https://github.com/stefanprojchev/ForgeBackgroundTasks) | Background task scheduling and dispatch. |
| **ForgeNetworking** | Typed, async/await-first HTTP networking with auth, retry, and background transfers. |
| [ForgeLog](https://github.com/stefanprojchev/ForgeLog) | Structured logging with pluggable providers and a built-in inspector UI. |
| [ForgeAccess](https://github.com/stefanprojchev/ForgeAccess) | Subscription-aware feature gating with override channels and debug UI. |

## License

ForgeNetworking is released under the MIT License. See [LICENSE](LICENSE).
