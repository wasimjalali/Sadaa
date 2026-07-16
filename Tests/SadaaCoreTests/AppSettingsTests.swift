import Testing
import Foundation
@testable import SadaaCore

@Suite(.serialized) struct AppSettingsTests {
    private let defaults: UserDefaults
    private let settings: AppSettings

    init() {
        defaults = UserDefaults(suiteName: "ai.karko.sadaa.tests")!
        // Clear persisted state before constructing settings so tests start clean.
        defaults.removePersistentDomain(forName: "ai.karko.sadaa.tests")
        settings = AppSettings(defaults: defaults)
    }

    @Test func testDefaults() {
        #expect(settings.speechProviderKind == .azureOpenAI)
        #expect(SpeechProviderKind.allCases == [.azureOpenAI, .openAICompatible])
        #expect(settings.azureAPIVersion == "2025-03-01-preview")
        #expect(settings.languagePin == .auto)
        #expect(settings.silenceTimeout == 60)
        #expect(settings.recordingsToKeep == 10)
        #expect(settings.azureEndpoint == "")
        #expect(settings.azureDeployment == "")
        #expect(settings.compatibleEndpoint == "")
        #expect(settings.compatibleModel == "whisper-1")
        #expect(settings.transcriptionPreset == .fast)
        #expect(TranscriptionPreset.allCases == [.fast, .accurate])
        #expect(settings.fastTranscriptionDeployment == "gpt-4o-mini-transcribe")
        #expect(settings.accurateTranscriptionDeployment == "gpt-4o-transcribe")
        #expect(settings.hotkeyKeycode == 54)          // Right Command
        #expect(settings.languageSwitchKeycode == 60)  // Right Shift (under Return)
        #expect(settings.soundEffectsEnabled == true)
    }

    @Test func testRoundTrip() {
        settings.speechProviderKind = .openAICompatible
        settings.azureEndpoint = "https://myres.openai.azure.com"
        settings.azureDeployment = "whisper"
        settings.transcriptionPreset = .accurate
        settings.fastTranscriptionDeployment = "fast"
        settings.accurateTranscriptionDeployment = "accurate"
        settings.languagePin = .de
        settings.silenceTimeout = 45.5
        settings.recordingsToKeep = 5
        settings.hotkeyKeycode = 61
        settings.languageSwitchKeycode = 63
        settings.compatibleEndpoint = "http://127.0.0.1:8080"
        settings.compatibleModel = "whisper-large-v3"
        #expect(settings.speechProviderKind == .openAICompatible)
        #expect(settings.azureEndpoint == "https://myres.openai.azure.com")
        #expect(settings.azureDeployment == "whisper")
        #expect(settings.transcriptionPreset == .accurate)
        #expect(settings.fastTranscriptionDeployment == "fast")
        #expect(settings.accurateTranscriptionDeployment == "accurate")
        #expect(settings.languagePin == .de)
        #expect(settings.silenceTimeout == 45.5)
        #expect(settings.recordingsToKeep == 5)
        #expect(settings.hotkeyKeycode == 61)
        #expect(settings.languageSwitchKeycode == 63)
        #expect(settings.compatibleEndpoint == "http://127.0.0.1:8080")
        #expect(settings.compatibleModel == "whisper-large-v3")
    }

    @Test func testTwoHotkeysSwapWhenTheyCollide() {
        var assignment = HotkeyAssignment(dictation: 54, languageSwitch: 60)

        assignment.setDictation(60)
        #expect(assignment.dictation == 60)
        #expect(assignment.languageSwitch == 54)

        assignment.setLanguageSwitch(60)
        #expect(assignment.dictation == 54)
        #expect(assignment.languageSwitch == 60)
    }

    @Test func testQuickToggleFlipsEnglishAndGerman() {
        #expect(LanguagePin.en.quickToggled == .de)
        #expect(LanguagePin.de.quickToggled == .en)
        // From auto the first tap lands on English, then it alternates.
        #expect(LanguagePin.auto.quickToggled == .en)
        #expect(LanguagePin.auto.quickToggled.quickToggled == .de)
    }
}
