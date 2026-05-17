# ForgeNetworking — Roadmap

v1.3 closed the meaningful gaps for a production HTTP client. Future work splits naturally into three companion packages, each scoped to a coherent concern that doesn't belong in the core networking layer.

## Companion packages (planned, not started)

### `ForgeRealtime`

Long-lived connections sharing ForgeNetworking's auth, interceptor, and retry abstractions:

- WebSocket client (`URLSessionWebSocketTask` under the hood, AsyncStream API)
- Server-Sent Events (SSE) with reconnect + last-event-id
- gRPC over HTTP/2 (separate consideration — Protobuf body type prereq)

### `ForgeAPI`

Higher-level conveniences built on `Endpoint`:

- Pagination helpers (cursor / offset / page-based AsyncSequence wrappers)
- URL path templates / interpolation
- GraphQL endpoint protocol + `data` / `errors` decoding
- Response envelopes (`{ data: T, meta: M }`) helper
- OpenAPI / Swagger code generation tool

### `ForgeNetworkingObservability`

Optional observability layer for apps that need more than the built-in `MetricsReporter`:

- W3C distributed tracing (`traceparent` / `tracestate` headers)
- OpenTelemetry integration
- Server-Timing header parsing
- Slow-request alerting rules

## Niche items deliberately not on the roadmap

These come up occasionally but are better handled as app-side helpers or with dedicated libraries:

- HTTP/3 / QUIC opt-in — twiddle `sessionConfiguration` directly
- mTLS / HMAC signing / AWS SigV4 — wire as a `RequestInterceptor`; an example > a built-in
- OAuth 2.0 PKCE / OIDC discovery — separate auth flow module
- Reachability-driven offline queueing — use `ForgeObservers.Connectivity` directly
- Circuit breaker / request hedging — over-engineering for typical apps
- Body compression / connection prewarming / request prioritization — premature optimization
- True streaming multipart / TUS / chunked uploads — niche
- Record/replay test mode — use snapshot-testing or a fixture library
- SwiftUI `@NetworkRequest` property wrapper — better as a thin app-side helper
- Combine bridge — async/await is the path forward
- ETag store for servers that don't send Cache-Control — handle in an app-side interceptor

## Open issues

None known. Cross-suite `MockURLProtocol.handler` race was fixed in v1.3 (commit `ec06184`).

## Contributing additions

Open a GitHub issue with the use case before opening a PR. Items that fit the companion packages above will get pointed there; items that genuinely belong in core will get a brainstorm-and-design pass first.
