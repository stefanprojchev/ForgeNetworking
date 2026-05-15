/// Marker refinement for endpoints that opt into upload progress streaming.
/// Use with `NetworkClient.sendWithProgress(_:)`.
public protocol ProgressReportingEndpoint: Endpoint {}
