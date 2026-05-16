import Testing
import Foundation
@testable import ForgeNetworking

@Suite("HTTPMethod Hashable / equality")
struct HTTPMethodEqualityTests {

    @Test("All standard methods are distinct in a Set")
    func allStandardMethodsDistinct() {
        let methods: Set<HTTPMethod> = [
            .get, .head, .post, .put, .patch,
            .delete, .options, .trace, .connect
        ]
        #expect(methods.count == 9)
    }

    @Test(".custom preserves value equality and hashes consistently")
    func customEquality() {
        #expect(HTTPMethod.custom("FOO") == .custom("FOO"))

        var set: Set<HTTPMethod> = []
        set.insert(.custom("FOO"))
        set.insert(.custom("FOO"))
        #expect(set.count == 1)
    }

    @Test("Distinct .custom variants are not equal")
    func distinctCustomVariants() {
        #expect(HTTPMethod.custom("FOO") != .custom("BAR"))

        var set: Set<HTTPMethod> = []
        set.insert(.custom("FOO"))
        set.insert(.custom("BAR"))
        #expect(set.count == 2)
    }
}
