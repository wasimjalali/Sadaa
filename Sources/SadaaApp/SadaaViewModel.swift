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
    @Published var dictionaryEntries: [DictionaryEntry] = []
    @Published var dictionarySuggestions: [String] = []

    private let settings: AppSettings
    private let history: DictationHistory
    private let dictionary: DictionaryStore
    private let onToggle: () -> Void

    /// History pages read search/all directly off the store.
    var historyStore: DictationHistory { history }

    init(settings: AppSettings, history: DictationHistory,
         dictionary: DictionaryStore, onToggle: @escaping () -> Void) {
        self.settings = settings
        self.history = history
        self.dictionary = dictionary
        self.onToggle = onToggle
        refreshConfig()
        refreshRecent()
        refreshDictionary()
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

    // MARK: - Dictionary

    func refreshDictionary() {
        dictionaryEntries = dictionary.all()
        dictionarySuggestions = dictionary.pendingSuggestions()
    }

    func addDictionaryWord(_ word: String, soundsLike: String?) {
        let alias = (soundsLike?.isEmpty == false) ? soundsLike : nil
        dictionary.add(word: word, soundsLike: alias)
        refreshDictionary()
    }

    func removeDictionaryEntry(_ id: UUID) {
        dictionary.remove(id: id)
        refreshDictionary()
    }

    func acceptSuggestion(_ term: String) {
        dictionary.accept(term)
        refreshDictionary()
    }

    func dismissSuggestion(_ term: String) {
        dictionary.dismiss(term)
        refreshDictionary()
    }
}
