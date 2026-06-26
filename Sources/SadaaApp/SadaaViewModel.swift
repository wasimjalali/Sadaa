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
    @Published var snippets: [Snippet] = []
    @Published var notes: [Note] = []
    @Published var monthlyCost = CostMeter.Totals(minutes: 0, cost: 0)
    /// Whether the global hotkey tap is actually running (Accessibility granted).
    @Published var hotkeyActive: Bool = false
    @Published var hotkeyKeycode: Int = 54
    @Published var voiceEditKeycode: Int = 61
    @Published var languageSwitchKeycode: Int = 60
    /// A failed dictation whose audio is retained and can be retried.
    @Published var canRetry: Bool = false

    /// Set by the app layer to push a new activation key to the live HotkeyManager.
    var onHotkeyKeycodeChange: ((Int) -> Void)?
    /// Set by the app layer to push a new voice-edit key to the live HotkeyManager.
    var onVoiceEditKeycodeChange: ((Int) -> Void)?
    /// Set by the app layer to push a new language-switch key to the live HotkeyManager.
    var onLanguageSwitchKeycodeChange: ((Int) -> Void)?
    /// Set by the app layer to retry the last failed dictation on its audio.
    var onRetry: (() -> Void)?

    private let settings: AppSettings
    private let history: DictationHistory
    private let dictionary: DictionaryStore
    private let snippetStore: SnippetStore
    private let notesStore: NotesStore
    private let onToggle: () -> Void

    /// History pages read search/all directly off the store.
    var historyStore: DictationHistory { history }

    init(settings: AppSettings, history: DictationHistory,
         dictionary: DictionaryStore, snippets: SnippetStore,
         notes: NotesStore, onToggle: @escaping () -> Void) {
        self.settings = settings
        self.history = history
        self.dictionary = dictionary
        self.snippetStore = snippets
        self.notesStore = notes
        self.onToggle = onToggle
        refreshConfig()
        refreshRecent()
        refreshDictionary()
        refreshSnippets()
        refreshNotes()
        refreshCost()
    }

    func toggle() { onToggle() }

    func retry() { onRetry?() }

    func refreshState(_ state: DictationState) { dictationState = state }

    func refreshRecent() { recent = history.recent(5) }

    func refreshCost() {
        monthlyCost = CostMeter.monthlyTotals(records: history.all(), now: Date())
    }

    func refreshConfig() {
        // exists() not get(): refreshConfig runs on the main thread (init, and
        // after every settings/language change), and get() can trigger a
        // blocking keychain authorization prompt that freezes the app, and with
        // it the HUD. An existence check is all "configured?" needs and never
        // prompts. See Keychain.exists.
        azureConfigured =
            !settings.azureEndpoint.isEmpty &&
            !settings.azureDeployment.isEmpty &&
            Keychain.exists(account: "azure-openai-key")
        languagePin = settings.languagePin
        hotkeyKeycode = settings.hotkeyKeycode
        voiceEditKeycode = settings.voiceEditKeycode
        languageSwitchKeycode = settings.languageSwitchKeycode
    }

    // The three tap-keys (dictation, voice-edit, language-switch) must always be
    // pairwise distinct: one CGEvent tap can't disambiguate two keys bound to the
    // same keycode. Each setter below swaps the colliding key to the value this
    // key just freed, which is guaranteed distinct from both the new value and
    // the untouched third key, so the invariant holds after every change.

    private func applyHotkey(_ code: Int) {
        settings.hotkeyKeycode = code
        hotkeyKeycode = code
        onHotkeyKeycodeChange?(code)
    }

    private func applyVoiceEdit(_ code: Int) {
        settings.voiceEditKeycode = code
        voiceEditKeycode = code
        onVoiceEditKeycodeChange?(code)
    }

    private func applyLanguageSwitch(_ code: Int) {
        settings.languageSwitchKeycode = code
        languageSwitchKeycode = code
        onLanguageSwitchKeycodeChange?(code)
    }

    /// Sets the dictation key, swapping whichever other key collides onto this
    /// key's previous value so all three stay distinct.
    func setHotkeyKeycode(_ code: Int) {
        let freed = hotkeyKeycode
        if code == voiceEditKeycode { applyVoiceEdit(freed) }
        else if code == languageSwitchKeycode { applyLanguageSwitch(freed) }
        applyHotkey(code)
    }

    /// Sets the voice-edit key, swapping the colliding key out of the way.
    func setVoiceEditKeycode(_ code: Int) {
        let freed = voiceEditKeycode
        if code == hotkeyKeycode { applyHotkey(freed) }
        else if code == languageSwitchKeycode { applyLanguageSwitch(freed) }
        applyVoiceEdit(code)
    }

    /// Sets the language-switch key, swapping the colliding key out of the way.
    func setLanguageSwitchKeycode(_ code: Int) {
        let freed = languageSwitchKeycode
        if code == hotkeyKeycode { applyHotkey(freed) }
        else if code == voiceEditKeycode { applyVoiceEdit(freed) }
        applyLanguageSwitch(code)
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

    // MARK: - Snippets

    func refreshSnippets() { snippets = snippetStore.all() }

    func addSnippet(trigger: String, expansion: String) {
        snippetStore.add(trigger: trigger, expansion: expansion)
        refreshSnippets()
    }

    func removeSnippet(_ id: UUID) {
        snippetStore.remove(id: id)
        refreshSnippets()
    }

    // MARK: - Notes

    func refreshNotes() { notes = notesStore.all() }

    func addNote(_ text: String) {
        notesStore.add(text: text, createdAt: Date())
        refreshNotes()
    }

    func removeNote(_ id: UUID) {
        notesStore.remove(id: id)
        refreshNotes()
    }

    func updateNote(_ id: UUID, text: String) {
        notesStore.update(id: id, text: text)
        refreshNotes()
    }
}
