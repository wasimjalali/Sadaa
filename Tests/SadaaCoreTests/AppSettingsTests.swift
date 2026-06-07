import Testing
import Foundation
@testable import SadaaCore

@Suite(.serialized) struct AppSettingsTests {
    private let defaults: UserDefaults
    private let settings: AppSettings

    init() {
        defaults = UserDefaults(suiteName: "ai.karko.sadaa.tests")!
        defaults.removePersistentDomain(forName: "ai.karko.sadaa.tests")
        settings = AppSettings(defaults: defaults)
    }

    @Test func testDefaults() {
        #expect(settings.azureAPIVersion == "2024-10-21")
        #expect(settings.languagePin == .auto)
        #expect(settings.silenceTimeout == 60)
        #expect(settings.recordingsToKeep == 10)
        #expect(settings.azureEndpoint == "")
        #expect(settings.azureDeployment == "")
    }

    @Test func testRoundTrip() {
        settings.azureEndpoint = "https://myres.openai.azure.com"
        settings.azureDeployment = "whisper"
        settings.languagePin = .de
        #expect(settings.azureEndpoint == "https://myres.openai.azure.com")
        #expect(settings.azureDeployment == "whisper")
        #expect(settings.languagePin == .de)
    }
}
