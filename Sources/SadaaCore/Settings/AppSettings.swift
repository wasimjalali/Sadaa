import Foundation

public enum LanguagePin: String, CaseIterable, Sendable {
    case auto, en, de

    /// The next language for the quick-switch key: a straight English<->German
    /// flip. From `.auto`, the first tap lands on English, then it alternates.
    public var quickToggled: LanguagePin {
        switch self {
        case .en: return .de
        case .de: return .en
        case .auto: return .en
        }
    }
}

public enum TranscriptionPreset: String, CaseIterable, Sendable {
    case fast, accurate
}

public enum SpeechProviderKind: String, CaseIterable, Sendable {
    case azureOpenAI
    case openAICompatible
}

public struct HotkeyAssignment: Equatable, Sendable {
    public private(set) var dictation: Int
    public private(set) var languageSwitch: Int

    public init(dictation: Int, languageSwitch: Int) {
        self.dictation = dictation
        self.languageSwitch = languageSwitch
    }

    public mutating func setDictation(_ keycode: Int) {
        let previous = dictation
        if keycode == languageSwitch {
            languageSwitch = previous
        }
        dictation = keycode
    }

    public mutating func setLanguageSwitch(_ keycode: Int) {
        let previous = languageSwitch
        if keycode == dictation {
            dictation = previous
        }
        languageSwitch = keycode
    }
}

/// Non-secret app configuration. API keys live in Keychain, never here.
public final class AppSettings {
    private enum Keys {
        static let speechProviderKind = "speechProviderKind"
        static let azureEndpoint = "azureEndpoint"
        static let azureDeployment = "azureDeployment"
        static let transcriptionPreset = "transcriptionPreset"
        static let fastTranscriptionDeployment = "fastTranscriptionDeployment"
        static let accurateTranscriptionDeployment = "accurateTranscriptionDeployment"
        static let azureAPIVersion = "azureAPIVersion"
        static let compatibleEndpoint = "compatibleEndpoint"
        static let compatibleModel = "compatibleModel"
        static let languagePin = "languagePin"
        static let silenceTimeout = "silenceTimeout"
        static let recordingsToKeep = "recordingsToKeep"
        static let hotkeyKeycode = "hotkeyKeycode"
        static let languageSwitchKeycode = "languageSwitchKeycode"
        static let gptDeployment = "gptDeployment"
        static let formattingEnabled = "formattingEnabled"
        static let speakerContext = "speakerContext"
        static let transcriptionRatePerMinute = "transcriptionRatePerMinute"
        static let formatterRatePer1kChars = "formatterRatePer1kChars"
        static let soundEffectsEnabled = "soundEffectsEnabled"
        static let lastExportFolder = "lastExportFolder"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var speechProviderKind: SpeechProviderKind {
        get {
            SpeechProviderKind(rawValue: defaults.string(forKey: Keys.speechProviderKind) ?? "")
                ?? .azureOpenAI
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.speechProviderKind) }
    }

    public var azureEndpoint: String {
        get { defaults.string(forKey: Keys.azureEndpoint) ?? "" }
        set { defaults.set(newValue, forKey: Keys.azureEndpoint) }
    }

    public var azureDeployment: String {
        get { defaults.string(forKey: Keys.azureDeployment) ?? "" }
        set { defaults.set(newValue, forKey: Keys.azureDeployment) }
    }

    public var transcriptionPreset: TranscriptionPreset {
        get {
            TranscriptionPreset(rawValue: defaults.string(forKey: Keys.transcriptionPreset) ?? "")
                ?? .fast
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.transcriptionPreset) }
    }

    public var fastTranscriptionDeployment: String {
        get { defaults.string(forKey: Keys.fastTranscriptionDeployment) ?? "gpt-4o-mini-transcribe" }
        set { defaults.set(newValue, forKey: Keys.fastTranscriptionDeployment) }
    }

    public var accurateTranscriptionDeployment: String {
        get { defaults.string(forKey: Keys.accurateTranscriptionDeployment) ?? "gpt-4o-transcribe" }
        set { defaults.set(newValue, forKey: Keys.accurateTranscriptionDeployment) }
    }

    /// Default supports the gpt-4o-transcribe family (whisper-1 too). The older
    /// 2024-10-21 GA predates those models and rejects them.
    public var azureAPIVersion: String {
        get { defaults.string(forKey: Keys.azureAPIVersion) ?? "2025-03-01-preview" }
        set { defaults.set(newValue, forKey: Keys.azureAPIVersion) }
    }

    public var compatibleEndpoint: String {
        get { defaults.string(forKey: Keys.compatibleEndpoint) ?? "" }
        set { defaults.set(newValue, forKey: Keys.compatibleEndpoint) }
    }

    public var compatibleModel: String {
        get { defaults.string(forKey: Keys.compatibleModel) ?? "whisper-1" }
        set { defaults.set(newValue, forKey: Keys.compatibleModel) }
    }

    public var languagePin: LanguagePin {
        get { LanguagePin(rawValue: defaults.string(forKey: Keys.languagePin) ?? "") ?? .auto }
        set { defaults.set(newValue.rawValue, forKey: Keys.languagePin) }
    }

    /// Seconds of silence before recording auto-stops. Spec section 8.
    public var silenceTimeout: TimeInterval {
        get { defaults.object(forKey: Keys.silenceTimeout) as? TimeInterval ?? 60 }
        set { defaults.set(newValue, forKey: Keys.silenceTimeout) }
    }

    /// How many past recordings to retain for retry/debugging. Spec section 5.
    public var recordingsToKeep: Int {
        get { defaults.object(forKey: Keys.recordingsToKeep) as? Int ?? 10 }
        set { defaults.set(newValue, forKey: Keys.recordingsToKeep) }
    }

    /// Virtual keycode of the activation modifier key. Default 54 = Right Command.
    public var hotkeyKeycode: Int {
        get { defaults.object(forKey: Keys.hotkeyKeycode) as? Int ?? 54 }
        set { defaults.set(newValue, forKey: Keys.hotkeyKeycode) }
    }

    /// Virtual keycode of the language quick-switch key. Default 60 = Right Shift
    /// (the Shift key under the Return key) by explicit user choice. A clean tap
    /// flips the dictation language between English and German. A bare Shift tap
    /// can fire by accident during fast capitalization, so if that becomes a
    /// nuisance the key is changeable in Settings. The Settings layer keeps it
    /// distinct from the dictation key.
    public var languageSwitchKeycode: Int {
        get { defaults.object(forKey: Keys.languageSwitchKeycode) as? Int ?? 60 }
        set { defaults.set(newValue, forKey: Keys.languageSwitchKeycode) }
    }

    /// Azure GPT deployment used for smart formatting. Spec section 3.6.
    public var gptDeployment: String {
        get { defaults.string(forKey: Keys.gptDeployment) ?? "" }
        set { defaults.set(newValue, forKey: Keys.gptDeployment) }
    }

    /// Smart formatting on/off. Spec section 8 default: on.
    public var formattingEnabled: Bool {
        get { defaults.object(forKey: Keys.formattingEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.formattingEnabled) }
    }

    /// Soft chimes when dictation starts and stops. Default: on.
    public var soundEffectsEnabled: Bool {
        get { defaults.object(forKey: Keys.soundEffectsEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.soundEffectsEnabled) }
    }

    /// Editable speaker-context line fed to the formatter. Spec section 4.
    public var speakerContext: String {
        get {
            defaults.string(forKey: Keys.speakerContext) ??
            "The speaker is an AI specialist and founder; dictations are usually about AI engineering and dev tooling. Resolve ambiguous words toward that domain (\"cloud code\" means \"Claude Code\", \"codecs\" means \"Codex\")."
        }
        set { defaults.set(newValue, forKey: Keys.speakerContext) }
    }

    // MARK: - Cost meter rates (spec section 7)

    public var transcriptionRatePerMinute: Double {
        get { defaults.object(forKey: Keys.transcriptionRatePerMinute) as? Double ?? 0.006 }
        set { defaults.set(newValue, forKey: Keys.transcriptionRatePerMinute) }
    }

    public var formatterRatePer1kChars: Double {
        get { defaults.object(forKey: Keys.formatterRatePer1kChars) as? Double ?? 0.002 }
        set { defaults.set(newValue, forKey: Keys.formatterRatePer1kChars) }
    }

    public var lastExportFolder: String {
        get { defaults.string(forKey: Keys.lastExportFolder) ?? "" }
        set { defaults.set(newValue, forKey: Keys.lastExportFolder) }
    }
}
