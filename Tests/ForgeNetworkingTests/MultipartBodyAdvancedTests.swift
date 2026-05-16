import Testing
import Foundation
@testable import ForgeNetworking

@Suite("MultipartBody advanced")
struct MultipartBodyAdvancedTests {

    // MARK: - Test A: fileURL part is read from disk

    @Test("fileURL part is read from disk and included in output")
    func fileURLPartReadFromDisk() throws {
        // Write a temp source file
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("forge-multipart-source-\(UUID().uuidString).txt")
        let fileContents = "file-contents"
        try Data(fileContents.utf8).write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        var body = MultipartBody(boundary: "TESTBOUNDARY")
        body.append(fileURL: sourceURL, name: "upload", filename: "test.txt", contentType: "text/plain")

        let outputURL = try body.writeToTemporaryFile()
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let written = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(written.contains(fileContents), "Output should contain file contents '\(fileContents)'")
        #expect(written.contains("filename=\"test.txt\""), "Output should contain the filename")
        #expect(written.hasSuffix("--TESTBOUNDARY--\r\n"), "Output should end with closing boundary")
    }

    // MARK: - Test B: Multiple parts in one body

    @Test("Multiple parts produce correct boundary count and all part contents")
    func multiplePartsInOneBody() throws {
        var body = MultipartBody(boundary: "MULTI")
        body.append(field: "username", value: "stefan")
        body.append(data: Data("data-one".utf8), name: "file1", filename: "one.txt", contentType: "text/plain")
        body.append(data: Data("data-two".utf8), name: "file2", filename: "two.txt", contentType: "text/plain")

        // Write a temp file for the fileURL part
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("forge-multipart-multi-\(UUID().uuidString).bin")
        try Data("file-data".utf8).write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        body.append(fileURL: sourceURL, name: "attachment", filename: "att.bin", contentType: "application/octet-stream")

        let outputURL = try body.writeToTemporaryFile()
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let written = try String(contentsOf: outputURL, encoding: .utf8)

        // 4 parts → 4 opening boundaries (--MULTI\r\n) + 1 closing (--MULTI--\r\n) = 5 total occurrences of "--MULTI"
        // Count all occurrences of "--MULTI"
        let openingBoundary = "--MULTI\r\n"
        let closingBoundary = "--MULTI--\r\n"

        var openingCount = 0
        var searchRange = written.startIndex..<written.endIndex
        while let range = written.range(of: openingBoundary, range: searchRange) {
            openingCount += 1
            searchRange = range.upperBound..<written.endIndex
        }

        #expect(openingCount == 4, "Expected 4 opening boundary delimiters, got \(openingCount)")
        #expect(written.contains(closingBoundary), "Expected closing boundary")
        #expect(written.contains("stefan"), "Expected field value 'stefan'")
        #expect(written.contains("data-one"), "Expected data part 'data-one'")
        #expect(written.contains("data-two"), "Expected data part 'data-two'")
        #expect(written.contains("file-data"), "Expected file URL part 'file-data'")
    }

    // MARK: - Test C: Empty body emits only closing boundary

    @Test("Empty multipart body emits only the closing boundary")
    func emptyBodyEmitsClosingBoundary() throws {
        let body = MultipartBody(boundary: "B")
        let outputURL = try body.writeToTemporaryFile()
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let written = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(written == "--B--\r\n", "Expected exactly '--B--\\r\\n', got: \(written.debugDescription)")
    }
}
