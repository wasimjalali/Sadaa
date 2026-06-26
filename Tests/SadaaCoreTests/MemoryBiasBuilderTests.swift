import Testing
import Foundation
@testable import SadaaCore

@Suite struct MemoryBiasBuilderTests {
    @Test func testAlwaysAndHighTermsComeFirstAndCapApplies() {
        let now = Date()
        let normal = MemoryTerm(phrase: "Normal", updatedAt: now, usageCount: 0)
        let high = MemoryTerm(phrase: "High", pronunciations: ["hie"],
                              priority: .high, updatedAt: now, usageCount: 0)
        let always = MemoryTerm(phrase: "Always", aliases: ["Always Alias"],
                                priority: .always, updatedAt: now, usageCount: 0)

        let list = MemoryBiasBuilder.biasList(
            terms: [normal, high, always],
            baseVocabulary: ["Base"],
            budget: 4
        )

        #expect(list == ["Always", "Always Alias", "High", "hie"])
    }

    @Test func testDedupesAgainstBaseVocabulary() {
        let term = MemoryTerm(phrase: "Supabase", priority: .always)
        let list = MemoryBiasBuilder.biasList(
            terms: [term],
            baseVocabulary: ["supabase", "Karko"],
            budget: 10
        )
        #expect(list.filter { $0.localizedCaseInsensitiveContains("supabase") }.count == 1)
    }

    @Test func testLanguageSpecificTermsAreFilteredWhenLanguagePinned() {
        let english = MemoryTerm(phrase: "English Term", language: .en, priority: .always)
        let german = MemoryTerm(phrase: "German Term", language: .de, priority: .always)
        let automatic = MemoryTerm(phrase: "Shared Term", language: .auto, priority: .always)

        let list = MemoryBiasBuilder.biasList(
            terms: [english, german, automatic],
            baseVocabulary: [],
            budget: 10,
            language: .en
        )

        #expect(list.contains("English Term"))
        #expect(list.contains("Shared Term"))
        #expect(!list.contains("German Term"))
    }
}
