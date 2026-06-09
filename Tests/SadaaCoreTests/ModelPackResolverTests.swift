import Testing
@testable import SadaaCore

@Suite struct ModelPackResolverTests {
    @Test func testTrailingMentionResolvesToGPT() {
        let target = ModelPackResolver.resolve(
            transcript: "write a python script that prints the row count, this is for GPT",
            defaultTarget: .claude)
        #expect(target == .gpt)
    }

    @Test func testLeadingMentionResolvesToClaude() {
        let target = ModelPackResolver.resolve(
            transcript: "for Claude fix the bug where users get logged out in auth session",
            defaultTarget: .gpt)
        #expect(target == .claude)
    }

    @Test func testMentionBuriedMidTranscriptIsNotMatched() {
        // The phrase is well past the first 6 and last 8 words, so it is treated
        // as content, not routing metadata, and the default is kept.
        let target = ModelPackResolver.resolve(
            transcript: "add a setting that lets the user pick whether the export is for gpt or for some other tool and then save that choice to disk so it survives a relaunch",
            defaultTarget: .claude)
        #expect(target == .claude)
    }

    @Test func testGermanFuerGPTResolvesToGPT() {
        let target = ModelPackResolver.resolve(
            transcript: "schreib ein skript das eine csv liest, das ist für GPT",
            defaultTarget: .claude)
        #expect(target == .gpt)
    }

    @Test func testCaseInsensitive() {
        let target = ModelPackResolver.resolve(
            transcript: "FOR CLAUDE refactor the parser",
            defaultTarget: .gpt)
        #expect(target == .claude)
    }

    @Test func testNoMentionKeepsDefault() {
        let target = ModelPackResolver.resolve(
            transcript: "add a dark mode toggle to the settings page",
            defaultTarget: .generic)
        #expect(target == .generic)
    }

    @Test func testForGoogleResolvesToGemini() {
        let target = ModelPackResolver.resolve(
            transcript: "summarize this thread in three bullets, for google",
            defaultTarget: .claude)
        #expect(target == .gemini)
    }

    @Test func testClaudeDesktopImpliesClaude() {
        #expect(ModelPackResolver.appImpliedTarget(
            bundleID: "com.anthropic.claudefordesktop") == .claude)
    }

    @Test func testChatGPTDesktopImpliesGPT() {
        #expect(ModelPackResolver.appImpliedTarget(bundleID: "com.openai.chat") == .gpt)
    }

    @Test func testUnknownAppImpliesNothing() {
        #expect(ModelPackResolver.appImpliedTarget(bundleID: "com.apple.Terminal") == nil)
        #expect(ModelPackResolver.appImpliedTarget(bundleID: nil) == nil)
    }
}
