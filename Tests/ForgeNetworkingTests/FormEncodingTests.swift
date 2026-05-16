import Testing
import Foundation
@testable import ForgeNetworking

@Suite("Form encoding — repeated keys + nested")
struct FormEncodingTests {
    @Test("Duplicate-keys encoding: tags=a&tags=b")
    func duplicateKeys() throws {
        let body = RequestBody<Empty>.formItems(
            [("tags", .array(["a", "b", "c"]))],
            encoding: .duplicateKeys
        )
        let encoded = try BodyEncoder.encode(body, encoder: JSONEncoder())
        let raw = String(data: encoded.payload!.data!, encoding: .utf8)!
        #expect(raw == "tags=a&tags=b&tags=c")
    }

    @Test("Bracketed encoding: tags[]=a&tags[]=b")
    func bracketedKeys() throws {
        let body = RequestBody<Empty>.formItems(
            [("tags", .array(["a", "b"]))],
            encoding: .bracketed
        )
        let encoded = try BodyEncoder.encode(body, encoder: JSONEncoder())
        let raw = String(data: encoded.payload!.data!, encoding: .utf8)!
        // URLComponents percent-encodes "[" and "]" — accept both raw and encoded forms
        #expect(raw == "tags[]=a&tags[]=b" || raw == "tags%5B%5D=a&tags%5B%5D=b")
    }

    @Test("Nested values: user[name]=alice")
    func nestedValues() throws {
        let body = RequestBody<Empty>.formItems(
            [("user", .nested(["name": .string("alice"), "email": .string("a@x.test")]))],
            encoding: .duplicateKeys
        )
        let encoded = try BodyEncoder.encode(body, encoder: JSONEncoder())
        let raw = String(data: encoded.payload!.data!, encoding: .utf8)!
        // Order is dictionary-iteration order, so accept both
        let possibilities = [
            "user[name]=alice&user[email]=a@x.test",
            "user[email]=a@x.test&user[name]=alice",
            "user%5Bname%5D=alice&user%5Bemail%5D=a@x.test",
            "user%5Bemail%5D=a@x.test&user%5Bname%5D=alice",
            // Email @ may also be percent-encoded
            "user%5Bname%5D=alice&user%5Bemail%5D=a%40x.test",
            "user%5Bemail%5D=a%40x.test&user%5Bname%5D=alice",
        ]
        #expect(possibilities.contains(raw))
    }

    @Test("Existing .form([String: String]) still works")
    func backwardsCompatible() throws {
        let body: RequestBody<Empty> = .form(["a": "1", "b": "two words"])
        let encoded = try BodyEncoder.encode(body, encoder: JSONEncoder())
        let raw = String(data: encoded.payload!.data!, encoding: .utf8)!
        #expect(raw.contains("a=1"))
        #expect(raw.contains("b=two%20words") || raw.contains("b=two+words"))
    }

    @Test("Mixed scalar and array items")
    func mixedItems() throws {
        let body = RequestBody<Empty>.formItems(
            [
                ("q", .string("hello")),
                ("filters", .array(["new", "popular"])),
            ],
            encoding: .duplicateKeys
        )
        let encoded = try BodyEncoder.encode(body, encoder: JSONEncoder())
        let raw = String(data: encoded.payload!.data!, encoding: .utf8)!
        #expect(raw.contains("q=hello"))
        #expect(raw.contains("filters=new"))
        #expect(raw.contains("filters=popular"))
    }
}
