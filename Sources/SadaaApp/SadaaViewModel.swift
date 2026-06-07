import SwiftUI
import SadaaCore

/// Bridges the dictation pipeline and stored settings/history into observable
/// state for the main window. Lives on the main actor like the rest of the UI.
@MainActor
final class SadaaViewModel: ObservableObject {
    @Published var dictationState: DictationState = .idle
    @Published var recent: [DictationRecord] = []
    @Published var azureConfigured: Bool = false
    @Published var languagePin: LanguagePin = .auto

    private let settings: AppSettings
    private let history: DictationHistory
    private let onToggle: () -> Void

    /// History pages read search/all directly off the store.
    var historyStore: DictationHistory { history }

    init(settings: AppSettings, history: DictationHistory, onToggle: @escaping () -> Void) {
        self.settings = settings
        self.history = history
        self.onToggle = onToggle
        refreshConfig()
        refreshRecent()
    }

    func toggle() { onToggle() }

    func refreshState(_ state: DictationState) { dictationState = state }

    func refreshRecent() { recent = history.recent(5) }

    func refreshConfig() {
        azureConfigured =
            !settings.azureEndpoint.isEmpty &&
            !settings.azureDeployment.isEmpty &&
            (Keychain.get(account: "azure-openai-key")?.isEmpty == false)
        languagePin = settings.languagePin
    }
}
