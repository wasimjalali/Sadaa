import Testing
@testable import SadaaCore

@Suite struct FormattingProfileTests {
    @Test func testResolvesCodeProfile() {
        let p = FormattingProfiles.resolve(bundleID: "com.microsoft.VSCode")
        #expect(p.name == "Prompt/code")
    }

    @Test func testBunyanResolvesToCodeProfile() {
        // Bunyan is the user's personal terminal; it must be treated as a terminal.
        let p = FormattingProfiles.resolve(bundleID: "com.wasimjalali.bunyan")
        #expect(p.name == "Prompt/code")
    }

    @Test func testResolvesChatProfile() {
        let p = FormattingProfiles.resolve(bundleID: "com.tinyspeck.slackmacgap")
        #expect(p.name == "Chat")
    }

    @Test func testUnknownBundleFallsBackToDefault() {
        #expect(FormattingProfiles.resolve(bundleID: "com.unknown.app").name == "Default")
    }

    @Test func testNilBundleFallsBackToDefault() {
        #expect(FormattingProfiles.resolve(bundleID: nil).name == "Default")
    }
}
