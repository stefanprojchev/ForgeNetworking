/// Receives one `RequestMetric` per `send(_:)` call. Implementers typically forward to a
/// metrics backend (CloudWatch, Datadog, Firebase Performance, custom analytics).
///
/// The reporter is called asynchronously after the response returns (or the final error is
/// determined). It never blocks the caller.
public protocol MetricsReporter: Sendable {
    func record(_ metric: RequestMetric) async
}
