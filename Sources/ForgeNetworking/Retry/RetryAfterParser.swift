import Foundation

public enum RetryAfterParser {
    private static let httpDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    public static func parse(_ header: String?, now: Date = Date()) -> TimeInterval? {
        guard let header = header?.trimmingCharacters(in: .whitespaces), !header.isEmpty else { return nil }
        if let seconds = TimeInterval(header) {
            return max(0, seconds)
        }
        if let date = httpDateFormatter.date(from: header) {
            return max(0, date.timeIntervalSince(now))
        }
        return nil
    }
}
