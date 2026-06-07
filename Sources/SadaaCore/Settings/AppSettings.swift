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

    public var azureAPIVersion: String {
        get { defaults.string(forKey: Keys.azureAPIVersion) ?? "2024-10-21" }
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
}
