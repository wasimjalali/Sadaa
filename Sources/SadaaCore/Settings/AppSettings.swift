import Foundation

public enum LanguagePin: String, CaseIterable, Sendable {
    case auto, en, de
}

/// Non-secret app configuration. API keys live in Keychain, never here.
public final class AppSettings {
    private enum Keys {
        static let azureEndpoint = "azureEndpoint"
        static let azureDeployment = "azureDeployment"
        static let azureAPIVersion = "azureAPIVersion"
        static let languagePin = "languagePin"
        static let silenceTimeout = "silenceTimeout"
        static let recordingsToKeep = "recordingsToKeep"
        static let hotkeyKeycode = "hotkeyKeycode"
        static let voiceEditKeycode = "voiceEditKeycode"
        static let gptDeployment = "gptDeployment"
        static let formattingEnabled = "formattingEnabled"
        static let speakerContext = "speakerContext"
        static let openaiEnabled = "openaiEnabled"
        static let openaiModel = "openaiModel"
        static let maiEnabled = "maiEnabled"
        static let maiEndpoint = "maiEndpoint"
        static let maiApiVersion = "maiApiVersion"
        static let maiModel = "maiModel"
        static let transcriptionRatePerMinute = "transcriptionRatePerMinute"
        static let formatterRatePer1kChars = "formatterRatePer1kChars"
        static let soundEffectsEnabled = "soundEffectsEnabled"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var azureEndpoint: String {
        get { defaults.string(forKey: Keys.azureEndpoint) ?? "" }
        set { defaults.set(newValue, forKey: Keys.azureEndpoint) }
    }

    public var azureDeployment: String {
        get { defaults.string(forKey: Keys.azureDeployment) ?? "" }
        set { defaults.set(newValue, forKey: Keys.azureDeployment) }
    }

    /// Default supports the gpt-4o-transcribe family (whisper-1 too). The older
    /// 2024-10-21 GA predates those models and rejects them.
    public var azureAPIVersion: String {
        get { defaults.string(forKey: Keys.azureAPIVersion) ?? "2025-03-01-preview" }
        set { defaults.set(newValue, forKey: Keys.azureAPIVersion) }
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

    /// Virtual keycode of the activation modifier key. Default 54 = Right Command
    /// (voice-edit then takes the other right-side tap key, Right Option).
    public var hotkeyKeycode: Int {
        get { defaults.object(forKey: Keys.hotkeyKeycode) as? Int ?? 54 }
        set { defaults.set(newValue, forKey: Keys.hotkeyKeycode) }
    }

    /// Virtual keycode of the voice-edit modifier key. Default 61 = Right Option.
    /// Independent from the dictation key; the UI keeps the two distinct.
    public var voiceEditKeycode: Int {
        get { defaults.object(forKey: Keys.voiceEditKeycode) as? Int ?? 61 }
        set { defaults.set(newValue, forKey: Keys.voiceEditKeycode) }
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

    // MARK: - Fallback providers (spec sections 3.4, 3.5)

    /// OpenAI API fallback. Off until a key is saved. Spec section 3.4.
    public var openaiEnabled: Bool {
        get { defaults.bool(forKey: Keys.openaiEnabled) }
        set { defaults.set(newValue, forKey: Keys.openaiEnabled) }
    }

    public var openaiModel: String {
        get { defaults.string(forKey: Keys.openaiModel) ?? "whisper-1" }
        set { defaults.set(newValue, forKey: Keys.openaiModel) }
    }

    /// MAI / Azure Speech provider. Ships disabled. Spec section 3.3.
    public var maiEnabled: Bool {
        get { defaults.bool(forKey: Keys.maiEnabled) }
        set { defaults.set(newValue, forKey: Keys.maiEnabled) }
    }

    public var maiEndpoint: String {
        get { defaults.string(forKey: Keys.maiEndpoint) ?? "" }
        set { defaults.set(newValue, forKey: Keys.maiEndpoint) }
    }

    public var maiApiVersion: String {
        get { defaults.string(forKey: Keys.maiApiVersion) ?? "2025-10-15" }
        set { defaults.set(newValue, forKey: Keys.maiApiVersion) }
    }

    public var maiModel: String {
        get { defaults.string(forKey: Keys.maiModel) ?? "mai-transcribe-1.5" }
        set { defaults.set(newValue, forKey: Keys.maiModel) }
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
}
