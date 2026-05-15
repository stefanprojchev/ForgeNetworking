import Testing
import Foundation
@testable import ForgeNetworking

@Suite("RetryAfterParser")
struct RetryAfterParserTests {
    @Test("Parses delta-seconds form")
    func deltaSeconds() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let interval = RetryAfterParser.parse("30", now: now)
        #expect(interval == 30)
    }

    @Test("Parses HTTP-date form")
    func httpDate() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let later = now.addingTimeInterval(60)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let header = formatter.string(from: later)

        let interval = RetryAfterParser.parse(header, now: now)
        #expect(interval ?? 0 >= 59)
        #expect(interval ?? 0 <= 61)
    }

    @Test("Returns nil for unparsable input")
    func unparsable() {
        #expect(RetryAfterParser.parse("garbage", now: Date()) == nil)
        #expect(RetryAfterParser.parse(nil, now: Date()) == nil)
    }

    @Test("Negative seconds clamp to zero")
    func negativeClamps() {
        #expect(RetryAfterParser.parse("-5", now: Date()) == 0)
    }
}
