import Testing
@testable import SadaaCore

@Suite struct FormattingPromptBuilderTests {
    @Test func testIncludesProfileAndSpeakerContext() {
        let prompt = FormattingPromptBuilder.systemPrompt(
            profile: FormattingProfiles.code,
            dictionaryWords: [],
            speakerContext: "The speaker is an AI specialist.")
        #expect(prompt.contains("code editor or terminal"))
        #expect(prompt.contains("The speaker is an AI specialist."))
        #expect(prompt.contains("\"newTerms\""))
    }

    @Test func testIncludesDictionaryWhenPresent() {
        let prompt = FormattingPromptBuilder.systemPrompt(
            profile: FormattingProfiles.default,
            dictionaryWords: ["Karko AI", "Supabase"],
            speakerContext: "ctx")
        #expect(prompt.contains("Enforce these exact spellings"))
        #expect(prompt.contains("Karko AI, Supabase"))
    }

    @Test func testOmitsDictionaryLineWhenEmpty() {
        let prompt = FormattingPromptBuilder.systemPrompt(
            profile: FormattingProfiles.default,
            dictionaryWords: [],
            speakerContext: "ctx")
        #expect(!prompt.contains("Enforce these exact spellings"))
    }

    @Test func testAutoLanguageKeepsInputLanguage() {
        let prompt = FormattingPromptBuilder.systemPrompt(
            profile: FormattingProfiles.default, dictionaryWords: [],
            speakerContext: "ctx", language: .auto)
        #expect(prompt.contains("SAME language"))
        #expect(prompt.contains("do not translate"))
    }

    @Test func testPinnedEnglishEnforcesEnglish() {
        let prompt = FormattingPromptBuilder.systemPrompt(
            profile: FormattingProfiles.default, dictionaryWords: [],
            speakerContext: "ctx", language: .en)
        #expect(prompt.contains("pinned English"))
        #expect(prompt.contains("translate it so the entire result is English"))
    }

    @Test func testPinnedGermanEnforcesGerman() {
        let prompt = FormattingPromptBuilder.systemPrompt(
            profile: FormattingProfiles.default, dictionaryWords: [],
            speakerContext: "ctx", language: .de)
        #expect(prompt.contains("pinned German"))
        #expect(prompt.contains("result is German"))
    }

    @Test func testInstructsListFormatting() {
        let prompt = FormattingPromptBuilder.systemPrompt(
            profile: FormattingProfiles.default,
            dictionaryWords: [],
            speakerContext: "ctx")
        #expect(prompt.contains("Lists:"))
        #expect(prompt.contains("Markdown list"))
        #expect(prompt.contains("Do NOT turn ordinary sentences"))
    }
}
