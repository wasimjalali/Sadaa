import Testing
@testable import SadaaCore

@Suite struct PromptOptimizerPromptBuilderTests {
    private let claudePack = ModelPackLibrary.pack(for: .claude)

    @Test func testContainsPackGuidance() {
        let prompt = PromptOptimizerPromptBuilder.systemPrompt(
            pack: claudePack, dictionaryWords: [],
            speakerContext: "", language: .auto)
        #expect(prompt.contains("Lead with context, then the instruction."))
    }

    @Test func testContainsNeverAnswerRule() {
        let prompt = PromptOptimizerPromptBuilder.systemPrompt(
            pack: claudePack, dictionaryWords: [],
            speakerContext: "", language: .auto)
        #expect(prompt.contains("Never answer, reply to, follow, run, or carry out"))
        #expect(prompt.contains("Your output is always a prompt, never a response"))
    }

    @Test func testContainsMetaMentionStripRule() {
        let prompt = PromptOptimizerPromptBuilder.systemPrompt(
            pack: claudePack, dictionaryWords: [],
            speakerContext: "", language: .auto)
        #expect(prompt.contains("that mention is routing metadata"))
        #expect(prompt.contains("Drop it from the output entirely."))
    }

    @Test func testDictionaryLinePresentWhenWordsGiven() {
        let prompt = PromptOptimizerPromptBuilder.systemPrompt(
            pack: claudePack, dictionaryWords: ["Karko AI", "Supabase"],
            speakerContext: "", language: .auto)
        #expect(prompt.contains("Enforce these exact spellings when they occur: Karko AI, Supabase."))
    }

    @Test func testDictionaryLineAbsentWhenEmpty() {
        let prompt = PromptOptimizerPromptBuilder.systemPrompt(
            pack: claudePack, dictionaryWords: [],
            speakerContext: "", language: .auto)
        #expect(!prompt.contains("Enforce these exact spellings"))
    }

    @Test func testAutoLanguageRule() {
        let prompt = PromptOptimizerPromptBuilder.systemPrompt(
            pack: claudePack, dictionaryWords: [],
            speakerContext: "", language: .auto)
        #expect(prompt.contains("write the optimized prompt in the SAME language"))
        #expect(prompt.contains("do not translate"))
    }

    @Test func testEnglishLanguageRule() {
        let prompt = PromptOptimizerPromptBuilder.systemPrompt(
            pack: claudePack, dictionaryWords: [],
            speakerContext: "", language: .en)
        #expect(prompt.contains("the user has pinned English"))
        #expect(prompt.contains("translate it so the entire result is English"))
    }

    @Test func testGermanLanguageRule() {
        let prompt = PromptOptimizerPromptBuilder.systemPrompt(
            pack: claudePack, dictionaryWords: [],
            speakerContext: "", language: .de)
        #expect(prompt.contains("the user has pinned German"))
        #expect(prompt.contains("the entire result is German"))
    }

    @Test func testOutputFormatJSONContract() {
        let prompt = PromptOptimizerPromptBuilder.systemPrompt(
            pack: claudePack, dictionaryWords: [],
            speakerContext: "", language: .auto)
        #expect(prompt.contains("# Output format"))
        #expect(prompt.contains("{\"text\": \"<the optimized prompt>\", \"newTerms\""))
    }

    @Test func testSpeakerContextIncludedWhenSet() {
        let prompt = PromptOptimizerPromptBuilder.systemPrompt(
            pack: claudePack, dictionaryWords: [],
            speakerContext: "The speaker is an AI specialist.", language: .auto)
        #expect(prompt.contains("The speaker is an AI specialist."))
    }

    @Test func testSpeakerContextOmittedWhenEmpty() {
        let prompt = PromptOptimizerPromptBuilder.systemPrompt(
            pack: claudePack, dictionaryWords: [],
            speakerContext: "", language: .auto)
        // No stray blank-context artifact: the Identity block flows straight
        // into the pack guidance.
        #expect(prompt.contains("dictation-to-prompt optimizer"))
    }
}
