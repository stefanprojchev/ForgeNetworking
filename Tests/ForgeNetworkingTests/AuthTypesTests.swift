import Testing
@testable import ForgeNetworking

@Suite("Auth foundational types")
struct AuthTypesTests {
    @Test("InMemoryTokenStore stores and clears tokens")
    func inMemoryTokenStore() async {
        let store = InMemoryTokenStore()
        await store.set(TokenPair(accessToken: "a", refreshToken: "r"))
        let pair = await store.current()
        #expect(pair?.accessToken == "a")
        #expect(pair?.refreshToken == "r")
        await store.clear()
        let cleared = await store.current()
        #expect(cleared == nil)
    }
}
