# ForgeNetworking — Future Enhancements

A catalog of capabilities not in v1.0.0. Grouped by theme. Each entry has a one-line description and a rough size estimate (**S** = days, **M** = a week or two, **L** = a few weeks, **XL** = its own package).

Items marked **[explicit non-goal in v1]** were deliberately deferred during the original design — see `docs/superpowers/specs/2026-05-15-forge-networking-design.md` § Out of scope.

---

## 1 · Transport protocols

| Item | Size | Notes |
|---|---|---|
| **WebSocket client** | XL | Probably its own `ForgeRealtime` package. URLSession's `URLSessionWebSocketTask` as the base; AsyncStream-based API for messages. **[non-goal in v1]** |
| **Server-Sent Events (SSE)** | M | Long-lived GET with `text/event-stream` parsing. Could live in `ForgeRealtime`. **[non-goal in v1]** |
| **AsyncSequence response streaming** | M | `client.stream(endpoint)` returning `AsyncThrowingStream<Data, Error>` for chunked responses (NDJSON, gRPC-Web, log tails). Uses `URLSession.bytes(for:)`. |
| **HTTP/3 / QUIC explicit opt-in** | S | URLSessionConfiguration supports it; expose a flag on `NetworkConfiguration`. |
| **gRPC over HTTP/2** | XL | Separate package. Protobuf body type would be a prereq. |

---

## 2 · Caching

| Item | Size | Notes |
|---|---|---|
| **URLCache + ETag / If-None-Match helpers** | M | Conditional GET with automatic 304 handling. Currently relies on URLSession's default cache only. **[non-goal in v1]** |
| **Stale-while-revalidate** | M | Return cached value immediately, fire background revalidation. Pairs with response caching above. |
| **Per-endpoint cache policy** | S | Add `var cachePolicy: URLRequest.CachePolicy?` to `Endpoint`. |
| **Custom cache backend (disk, in-memory, encrypted)** | M | A `ResponseCache` protocol that callers can implement, e.g., backed by `ForgeCrypt`. |

---

## 3 · Security

| Item | Size | Notes |
|---|---|---|
| **Certificate / public-key pinning** | M | `URLSessionDelegate` hook with a pluggable pinning policy. **[non-goal in v1]** — currently apps wire their own delegate. |
| **mTLS (client certificates)** | M | Configurable client identity in `NetworkConfiguration`; URLSession handles the handshake. |
| **Request signing — HMAC-SHA256** | S | `HMACRequestSigner` as a `RequestInterceptor`. |
| **Request signing — AWS SigV4** | M | More involved (canonical request, scope, derived key). Useful for S3, API Gateway. |
| **Body encryption at rest** | S | Combined with `ForgeCrypt` for cases where the network is trusted but bodies must be sealed before persistence. |

---

## 4 · Authentication

| Item | Size | Notes |
|---|---|---|
| **OAuth 2.0 PKCE auth-code flow** | L | Full flow including the auth web view. Likely its own module. **[non-goal in v1]** — current Bearer provider accepts tokens from any source. |
| **OpenID Connect (OIDC) discovery + ID-token validation** | L | Builds on the above. |
| **Biometric-gated refresh** | S | Gate `RefreshCoordinator.refresh` behind LocalAuthentication, requiring Face ID / Touch ID before reading the refresh token. |
| **Token rotation policies** | S | Refresh-before-expiry rather than reactive on 401. Use `TokenPair.expiresAt` with a configurable headroom. |
| **mTLS / client certificate auth** | S | Once mTLS is in transport, expose it as an `AuthProvider` variant for completeness. |
| **AWS IAM role auth** | M | Federated identity → temporary creds → SigV4 signing. |

---

## 5 · Reliability

| Item | Size | Notes |
|---|---|---|
| **Idempotency-Key auto-injection** | S | Generate a UUID per retried POST, inject `Idempotency-Key` header, keep it stable across attempts. **[non-goal in v1]** |
| **Reachability-driven offline queueing** | M | Integrate with `ForgeObservers.Connectivity`. Persist pending requests, flush on reconnect. **[non-goal in v1]** |
| **Circuit breaker** | M | Per-host circuit that opens after N consecutive failures, half-open after a cooldown. |
| **Request hedging** | M | For latency-critical reads: fire a duplicate after a timeout, take whichever returns first. |
| **Bounded backoff with explicit deadline** | S | `RetryPolicy.deadline: TimeInterval?` — give up after total elapsed time, regardless of attempts. |
| **Per-status retry strategy** | S | Different backoff per status (e.g., 429 honors Retry-After tightly; 503 uses longer base). |

---

## 6 · Performance

| Item | Size | Notes |
|---|---|---|
| **Body compression (gzip / brotli)** | M | Encode request bodies + set `Content-Encoding`. URLSession handles inbound automatically. |
| **Connection prewarming / DNS prefetch** | S | Fire a HEAD on app launch to warm connection pool. |
| **Request prioritization** | S | Expose `URLSessionTask.priority` per endpoint. Default lower priority for prefetch endpoints. |
| **Request batching / coalescing** | M | Coalesce identical in-flight requests so concurrent callers share one network call. Common for image loaders. |
| **HTTP/2 multiplexing tuning** | S | Expose URLSession's `httpMaximumConnectionsPerHost`, currently controlled only via raw `sessionConfiguration`. |

---

## 7 · Observability

| Item | Size | Notes |
|---|---|---|
| **W3C distributed tracing (traceparent)** | M | Auto-inject `traceparent` / `tracestate` headers; integrate with OpenTelemetry. |
| **Telemetry hooks (request/response metrics)** | S | `MetricsReporter` protocol — calls `record(duration:bytesIn:bytesOut:statusCode:)` per request. |
| **Server-Timing header parsing** | S | Parse the response header into a structured `[ServerTiming]`. |
| **Per-route observability dashboards** | S | Tag every metric with the endpoint type name (`String(describing: type)`) so callers can group. |
| **Slow request logger** | S | Built-in interceptor that logs requests exceeding a configurable threshold. |

---

## 8 · Ergonomics

| Item | Size | Notes |
|---|---|---|
| **Pagination helpers** | M | `AsyncSequence` wrappers for cursor, offset, and page-based pagination on top of a base endpoint. |
| **URL path templates / interpolation** | S | A `@PathTemplate` macro or `PathTemplate("/users/:id")` builder to reduce string interpolation. |
| **Typed per-endpoint error decoding** | S | Add `associatedtype ErrorPayload: Decodable` to `Endpoint`, decode it for 4xx and surface as `.clientError(payload: ErrorPayload)`. |
| **GraphQL helpers** | M | `GraphQLEndpoint` protocol that wraps the query + variables into a single POST and decodes `data` / `errors`. |
| **Response envelopes (`{ data: T, meta: M }`) helper** | S | A protocol + extension that unwraps a common envelope shape automatically. |
| **SwiftUI `@NetworkRequest` property wrapper** | M | Declarative request from a SwiftUI view, with loading/error/data states. |
| **`async`-aware Combine bridge** | S | If the codebase mixes Combine. |
| **OpenAPI / Swagger code generation** | XL | Generate `Endpoint` types from an OpenAPI spec. Separate tool. |

---

## 9 · Multipart and uploads

| Item | Size | Notes |
|---|---|---|
| **True streaming multipart (no temp file)** | M | Implement an `InputStream`-backed multipart body so very large uploads never hit disk. Requires extending URLSession integration. |
| **Resumable foreground uploads (TUS protocol)** | L | Multi-part PATCH-based resumable upload protocol. Separate from background-session resume. |
| **Chunked upload with per-chunk progress** | M | Split a large file into chunks, upload sequentially with hash verification, support resume per chunk. |
| **Multipart from `[String: any Encodable]`** | S | Convenience builder that JSON-encodes scalar values and treats `URL` and `Data` as file parts. |

---

## 10 · Background transfers

| Item | Size | Notes |
|---|---|---|
| **Per-handle status query** | S | `backgroundClient.status(of: handle)` returning current bytes/total without subscribing to the events stream. |
| **Transfer persistence across launches** | M | Persist `TransferHandle` ↔ user-meaningful ID mapping so the app can re-associate restored transfers with UI state. |
| **Background upload chunking** | M | Combine with chunked upload above; OS-managed background transfers per chunk. |

---

## 11 · Testing & developer experience

| Item | Size | Notes |
|---|---|---|
| **Record / replay mode** | M | Real client wrapper that records request/response pairs to disk, then can replay them in tests without a network. |
| **HTTP fixture loader** | S | `XCTestCase` helper that loads `.json` / `.txt` files as canned responses for `MockNetworkClient`. |
| **Swagger / VCR-style cassette format** | S | A standard file format for fixtures so they're shareable between teams. |
| **Snapshot testing for requests** | S | Verify the exact URLRequest produced for a given endpoint (URL, headers, body) — catches breaking changes to endpoint definitions. |
| **Test plan: failure injection** | M | A `FailureInjectingClient` that randomly fails / delays / corrupts responses to find resilience bugs. |

---

## 12 · Known issues to address

| Item | Size | Notes |
|---|---|---|
| **Cross-suite `MockURLProtocol.handler` race** | S | Currently `nonisolated(unsafe) static var` — fine within a `.serialized` suite but not across parallel suites. Fix: thread the handler through a session instance (via `URLSessionConfiguration.protocolClasses`) keyed by a UUID, so each test gets its own. Allows unfiltered `swift test` to be reliable. |

---

## Themes that span multiple buckets

- **`ForgeRealtime` companion package** — WebSocket, SSE, and streaming responses, all sharing the same auth/interceptor abstractions but on long-lived connections.
- **`ForgeAPI` companion package** — Higher-level conveniences: pagination, GraphQL, typed errors, URL templates, OpenAPI codegen — built on ForgeNetworking primitives.
- **`ForgeNetworkingObservability`** — Distributed tracing, metrics, slow-request logging, Server-Timing — split out so apps that don't need it don't pull in dependencies.

---

## How to use this document

When deciding what to build next, pick along three axes:

1. **Stefan's app needs** — which entries unblock real work today?
2. **Cohesion with the Forge family** — items that pair naturally with `ForgeObservers`, `ForgeCrypt`, `ForgeBackgroundTasks` are higher leverage.
3. **API surface stability** — additive features (helpers, hooks) can ship freely; anything that changes `Endpoint` / `NetworkClient` should be batched into a v2 to avoid breaking consumers.

Open a GitHub issue (or a new spec under `docs/superpowers/specs/`) for any item you want to pursue, and we'll brainstorm + plan it through the normal flow.
