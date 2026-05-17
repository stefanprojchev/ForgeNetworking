/// Marker refinement for endpoints that opt into upload progress streaming.
/// Use with `NetworkClient.sendWithProgress(_:)`. Works for any body type that
/// produces an HTTP body — multipart, raw bytes, JSON, form — so progress is
/// available for both multipart uploads and large raw / JSON payloads.
public protocol ProgressReportingEndpoint: Endpoint {}
